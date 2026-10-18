using System.Text.RegularExpressions;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using BuildTask = Microsoft.Build.Utilities.Task;

namespace Novolis.MSBuild.ToolReference;

/// <summary>Resolves package-relative ToolReference entry points from the restored assets file.</summary>
public sealed class ResolveToolReferenceTask : BuildTask
{
    /// <summary>ToolReference items declared by the consuming project.</summary>
    [Required]
    public ITaskItem[] ToolReferences { get; set; } = Array.Empty<ITaskItem>();

    /// <summary>Path to the consuming project's restored assets file.</summary>
    [Required]
    public string AssetsFilePath { get; set; } = string.Empty;

    /// <summary>NuGet's global package root.</summary>
    [Required]
    public string NuGetPackageRoot { get; set; } = string.Empty;

    /// <summary>Resolved executable tool items.</summary>
    [Output]
    public ITaskItem[] ResolvedTools { get; private set; } = Array.Empty<ITaskItem>();

    /// <inheritdoc />
    public override bool Execute()
    {
        if (ToolReferences.Length == 0)
        {
            ResolvedTools = Array.Empty<ITaskItem>();
            return true;
        }

        if (!File.Exists(AssetsFilePath))
        {
            Log.LogError("ToolReference assets file was not found: {0}", AssetsFilePath);
            return false;
        }

        var assets = File.ReadAllText(AssetsFilePath);
        var resolved = new List<ITaskItem>(ToolReferences.Length);

        foreach (var toolReference in ToolReferences)
        {
            var packageId = toolReference.ItemSpec;
            var relativeToolPath = toolReference.GetMetadata("ToolPath");
            if (string.IsNullOrWhiteSpace(relativeToolPath))
            {
                Log.LogError("ToolReference '{0}' must specify ToolPath relative to its restored package.", packageId);
                continue;
            }

            var packageVersion = FindResolvedVersion(assets, packageId);
            if (packageVersion is null)
            {
                Log.LogError(
                    "ToolReference package '{0}' was not found in '{1}'. Restore the project before running the tool.",
                    packageId,
                    AssetsFilePath);
                continue;
            }

            var packageRoot = Path.GetFullPath(Path.Combine(
                NuGetPackageRoot,
                packageId.ToLowerInvariant(),
                packageVersion.ToLowerInvariant()));
            if (!Directory.Exists(packageRoot))
            {
                Log.LogError("Restored ToolReference package directory was not found: {0}", packageRoot);
                continue;
            }

            var toolPath = Path.GetFullPath(Path.Combine(packageRoot, relativeToolPath));
            if (!IsWithinDirectory(toolPath, packageRoot))
            {
                Log.LogError("ToolReference '{0}' has a ToolPath outside its package: {1}", packageId, relativeToolPath);
                continue;
            }

            if (!File.Exists(toolPath))
            {
                Log.LogError("ToolReference entry point was not found: {0}", toolPath);
                continue;
            }

            var resolvedTool = new TaskItem(toolPath);
            CopyMetadata(toolReference, resolvedTool, "ToolReferenceId", packageId);
            CopyMetadata(toolReference, resolvedTool, "Arguments");
            CopyMetadata(toolReference, resolvedTool, "WorkingDirectory");
            CopyMetadata(toolReference, resolvedTool, "Inputs");
            CopyMetadata(toolReference, resolvedTool, "Outputs");
            CopyMetadata(toolReference, resolvedTool, "RunOnBuild");
            CopyMetadata(toolReference, resolvedTool, "RunOnPack");
            CopyMetadata(toolReference, resolvedTool, "TimeoutMilliseconds");
            CopyMetadata(toolReference, resolvedTool, "VerifyArguments");
            resolved.Add(resolvedTool);
        }

        ResolvedTools = resolved.ToArray();
        return !Log.HasLoggedErrors;
    }

    private static string? FindResolvedVersion(string assets, string packageId)
    {
        var libraryPattern = "\"" + Regex.Escape(packageId) + @"/(?<version>[^""]+)""\s*:\s*\{";
        var libraryMatch = Regex.Match(
            assets,
            libraryPattern,
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        if (libraryMatch.Success)
        {
            return libraryMatch.Groups["version"].Value;
        }

        // PackageDownload records tool packages under framework
        // downloadDependencies instead of libraries.
        var downloadPattern =
            @"""name""\s*:\s*""" + Regex.Escape(packageId)
            + @"""\s*,\s*""version""\s*:\s*""(?<range>[^""]+)""";
        var downloadMatch = Regex.Match(
            assets,
            downloadPattern,
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        return downloadMatch.Success
            ? ExactVersionFromRange(downloadMatch.Groups["range"].Value)
            : null;
    }

    private static string? ExactVersionFromRange(string value)
    {
        var range = value.Trim();
        if (range.Length == 0)
        {
            return null;
        }

        if (range.Length >= 2 && range[0] == '[' && range[range.Length - 1] == ']')
        {
            var inner = range.Substring(1, range.Length - 2).Trim();
            var parts = inner.Split(',');
            if (parts.Length == 1)
            {
                return parts[0].Trim();
            }

            var lower = parts[0].Trim();
            var upper = parts[1].Trim();
            return string.Equals(lower, upper, StringComparison.OrdinalIgnoreCase)
                ? lower
                : null;
        }

        return range.IndexOfAny(new[] { '(', ')', '[', ']' }) >= 0 ? null : range;
    }

    private static bool IsWithinDirectory(string path, string directory)
    {
        var normalizedDirectory = directory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        return path.StartsWith(normalizedDirectory, StringComparison.OrdinalIgnoreCase);
    }

    private static void CopyMetadata(ITaskItem source, TaskItem destination, string name, string? fallback = null)
    {
        var value = source.GetMetadata(name);
        destination.SetMetadata(name, string.IsNullOrWhiteSpace(value) ? fallback ?? string.Empty : value);
    }
}
