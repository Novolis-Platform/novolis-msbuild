using System.Diagnostics;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using BuildTask = Microsoft.Build.Utilities.Task;

namespace Novolis.MSBuild.ToolReference;

/// <summary>Runs a resolved ToolReference without a shell or visible console window.</summary>
public sealed class RunToolReferenceTask : BuildTask, ICancelableTask
{
    private readonly object _processGate = new();
    private Process? _runningProcess;
    private bool _cancelRequested;

    /// <summary>Absolute path to the tool entry point.</summary>
    [Required]
    public string ToolPath { get; set; } = string.Empty;

    /// <summary>Arguments passed to the tool.</summary>
    public string Arguments { get; set; } = string.Empty;

    /// <summary>Working directory for the tool process.</summary>
    public string WorkingDirectory { get; set; } = string.Empty;

    /// <summary>Semicolon-separated input paths used for incremental skipping.</summary>
    public string Inputs { get; set; } = string.Empty;

    /// <summary>Semicolon-separated output paths used for incremental skipping.</summary>
    public string Outputs { get; set; } = string.Empty;

    /// <summary>Optional process timeout in milliseconds; zero means no timeout.</summary>
    public int TimeoutMilliseconds { get; set; }

    /// <inheritdoc />
    public override bool Execute()
    {
        if (!File.Exists(ToolPath))
        {
            Log.LogError("ToolReference entry point was not found: {0}", ToolPath);
            return false;
        }

        var workingDirectory = string.IsNullOrWhiteSpace(WorkingDirectory)
            ? Path.GetDirectoryName(ToolPath) ?? Environment.CurrentDirectory
            : WorkingDirectory;
        var startInfo = new ProcessStartInfo
        {
            FileName = IsManagedAssembly(ToolPath) ? "dotnet" : ToolPath,
            Arguments = IsManagedAssembly(ToolPath)
                ? QuoteArgument(ToolPath) + AddLeadingArguments(Arguments)
                : Arguments,
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

        if (IsUpToDate(Inputs, Outputs, workingDirectory))
        {
            Log.LogMessage(MessageImportance.Low, "ToolReference is up to date: {0}", ToolPath);
            return true;
        }

        using var process = new Process { StartInfo = startInfo };
        lock (_processGate)
        {
            _runningProcess = process;
            _cancelRequested = false;
        }

        try
        {
            if (!process.Start())
            {
                Log.LogError("Failed to start ToolReference: {0}", ToolPath);
                return false;
            }

            var standardOutput = process.StandardOutput.ReadToEndAsync();
            var standardError = process.StandardError.ReadToEndAsync();
            var timeout = TimeoutMilliseconds > 0 ? TimeoutMilliseconds : -1;
            if (!process.WaitForExit(timeout))
            {
                try
                {
                    process.Kill();
                }
                catch (InvalidOperationException)
                {
                }

                Log.LogError(
                    "ToolReference timed out after {0} ms: {1}",
                    TimeoutMilliseconds,
                    ToolPath);
                return false;
            }

            System.Threading.Tasks.Task.WaitAll(standardOutput, standardError);
            LogOutput(standardOutput.Result, MessageImportance.High);
            LogOutput(standardError.Result, MessageImportance.High);

            if (_cancelRequested)
            {
                Log.LogMessage(MessageImportance.High, "ToolReference canceled: {0}", ToolPath);
                return false;
            }

            if (process.ExitCode != 0)
            {
                Log.LogError(
                    "ToolReference exited with code {0}: {1}",
                    process.ExitCode,
                    ToolPath);
                return false;
            }

            return true;
        }
        catch (Exception ex)
        {
            if (_cancelRequested)
            {
                Log.LogMessage(MessageImportance.High, "ToolReference canceled: {0}", ToolPath);
                return false;
            }

            Log.LogErrorFromException(ex, showStackTrace: false, showDetail: true, file: ToolPath);
            return false;
        }
        finally
        {
            lock (_processGate)
            {
                _runningProcess = null;
            }
        }
    }

    /// <summary>Requests cancellation of the running tool process.</summary>
    public void Cancel()
    {
        Process? process;
        lock (_processGate)
        {
            _cancelRequested = true;
            process = _runningProcess;
        }

        if (process is null || process.HasExited)
        {
            return;
        }

        try
        {
            process.Kill();
        }
        catch (InvalidOperationException)
        {
            // The process exited between HasExited and Kill.
        }
    }

    private static bool IsManagedAssembly(string path) =>
        string.Equals(Path.GetExtension(path), ".dll", StringComparison.OrdinalIgnoreCase);

    private static string AddLeadingArguments(string arguments) =>
        string.IsNullOrWhiteSpace(arguments) ? string.Empty : " " + arguments;

    private static string QuoteArgument(string value) =>
        "\"" + value.Replace("\"", "\\\"") + "\"";

    private void LogOutput(string output, MessageImportance importance)
    {
        foreach (var line in output.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries))
        {
            Log.LogMessage(importance, "[ToolReference] {0}", line);
        }
    }

    private static bool IsUpToDate(string inputList, string outputList, string baseDirectory)
    {
        var inputs = SplitPaths(inputList, baseDirectory);
        var outputs = SplitPaths(outputList, baseDirectory);
        if (inputs.Length == 0 || outputs.Length == 0 || outputs.Any(path => !File.Exists(path)))
        {
            return false;
        }

        var newestInput = inputs
            .Where(File.Exists)
            .Select(File.GetLastWriteTimeUtc)
            .DefaultIfEmpty(DateTime.MinValue)
            .Max();
        var oldestOutput = outputs
            .Select(File.GetLastWriteTimeUtc)
            .Min();
        return oldestOutput >= newestInput;
    }

    private static string[] SplitPaths(string value, string baseDirectory) =>
        value.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(path => path.Trim())
            .Where(path => path.Length > 0)
            .Select(path => Path.IsPathRooted(path) ? path : Path.Combine(baseDirectory, path))
            .ToArray();
}
