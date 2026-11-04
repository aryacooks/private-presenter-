using System.Text;
using System.Text.Json;

namespace PrivatePresenter;

internal sealed class PresenterDocument
{
    public string Name { get; set; } = "Untitled document";
    public int CurrentPage { get; set; }
    public List<string> Pages { get; set; } = [BlankRtf];
    public const string BlankRtf = @"{\rtf1\ansi\deff0{\fonttbl{\f0 Segoe UI;}}\f0\fs44 }";

    public void Add()
    {
        Pages.Insert(++CurrentPage, BlankRtf);
    }

    public void Duplicate(int index)
    {
        Pages.Insert(index + 1, Pages[index]);
        CurrentPage = index + 1;
    }

    public void Delete(int index)
    {
        if (Pages.Count == 1) Pages[0] = BlankRtf;
        else
        {
            Pages.RemoveAt(index);
            if (index < CurrentPage) CurrentPage--;
        }
        CurrentPage = Math.Clamp(CurrentPage, 0, Pages.Count - 1);
    }

    public void Clear()
    {
        Pages = [BlankRtf];
        CurrentPage = 0;
    }
}

internal static class DocumentStore
{
    private sealed record Project(int Version, string Name, int CurrentPage, string[] Pages);
    private static readonly JsonSerializerOptions Options = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public static void Save(PresenterDocument document, string path)
    {
        var project = new Project(1, document.Name, document.CurrentPage,
            document.Pages.Select(page => Convert.ToBase64String(Encoding.UTF8.GetBytes(page))).ToArray());
        var folder = Path.GetDirectoryName(Path.GetFullPath(path))!;
        Directory.CreateDirectory(folder);
        var temporary = Path.Combine(folder, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(project, Options));
            File.Move(temporary, path, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    public static PresenterDocument Load(string path)
    {
        var project = JsonSerializer.Deserialize<Project>(File.ReadAllText(path), Options)
            ?? throw new InvalidDataException("The document is empty.");
        if (project.Version != 1 || project.Pages is null)
            throw new InvalidDataException("Unsupported presenter document version.");
        var pages = project.Pages.Select(page => Encoding.UTF8.GetString(Convert.FromBase64String(page))).ToList();
        if (pages.Count == 0) pages.Add(PresenterDocument.BlankRtf);
        // Validate every page before replacing the open document.
        using var editor = new RichTextBox();
        foreach (var page in pages) editor.Rtf = page;
        return new PresenterDocument
        {
            Name = project.Name ?? "Untitled document",
            CurrentPage = Math.Clamp(project.CurrentPage, 0, pages.Count - 1),
            Pages = pages
        };
    }
}
