if (args.Length != 2)
{
    Console.Error.WriteLine("Usage: CodeGenTool <input> <output>");
    return 2;
}

var input = Path.GetFullPath(args[0]);
var output = Path.GetFullPath(args[1]);
var content = File.ReadAllText(input);
Directory.CreateDirectory(Path.GetDirectoryName(output)!);
File.WriteAllText(output, $"Generated from {Path.GetFileName(input)}:{Environment.NewLine}{content}");
return 0;
