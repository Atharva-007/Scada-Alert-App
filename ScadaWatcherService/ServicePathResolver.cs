namespace ScadaWatcherService;

internal static class ServicePathResolver
{
    public static string BaseDirectory => AppContext.BaseDirectory;

    public static string ResolvePath(string? configuredPath)
    {
        if (string.IsNullOrWhiteSpace(configuredPath))
        {
            return BaseDirectory;
        }

        var expandedPath = Environment.ExpandEnvironmentVariables(configuredPath.Trim());
        return Path.IsPathRooted(expandedPath)
            ? expandedPath
            : Path.GetFullPath(expandedPath, BaseDirectory);
    }
}
