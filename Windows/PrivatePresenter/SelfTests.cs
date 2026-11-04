namespace PrivatePresenter;

internal static class SelfTests
{
    internal static void Run()
    {
        string folder = Path.Combine(Path.GetTempPath(), "PrivatePresenter-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        try
        {
            var document = new PresenterDocument();
            using var editor = new RichTextBox { Text = "Heading\nSecond line — café" };
            editor.Select(0, 7);
            editor.SelectionFont = new Font("Segoe UI", 36, FontStyle.Bold);
            editor.SelectionColor = Color.Red;
            document.Pages[0] = editor.Rtf;
            document.Add();
            document.Duplicate(0);
            Check(document.Pages.Count == 3 && document.Pages[0] == document.Pages[1], "Duplicate retains rich text");
            document.CurrentPage = 2;
            document.Delete(0);
            Check(document.CurrentPage == 1 && document.Pages.Count == 2, "Delete keeps selected page valid");
            document.CurrentPage = 0;
            string path = Path.Combine(folder, "Roundtrip.ppdoc");
            DocumentStore.Save(document, path);
            var restored = DocumentStore.Load(path);
            editor.Rtf = restored.Pages[0];
            Check(editor.Text.Contains("café"), "Unicode text survives project save/load");
            editor.Select(0, 7);
            Check(editor.SelectionFont?.Bold == true && Math.Abs(editor.SelectionFont.Size - 36) < .1,
                "Font size and emphasis survive project save/load");
            Check(editor.SelectionColor.ToArgb() == Color.Red.ToArgb(), "Colour survives project save/load");
            editor.ZoomFactor = 1.5f;
            Check(editor.Rtf == restored.Pages[0], "Zoom does not alter stored formatting");
            document.Clear();
            document.Delete(0);
            Check(document.Pages.Count == 1 && document.CurrentPage == 0, "Clear and final-page deletion leave one blank page");

            string invalid = Path.Combine(folder, "Invalid.ppdoc");
            File.WriteAllText(invalid, "{\"version\":2,\"name\":\"Future\",\"currentPage\":0,\"pages\":[]}");
            bool rejected = false;
            try { DocumentStore.Load(invalid); }
            catch (InvalidDataException) { rejected = true; }
            Check(rejected, "Unsupported project version is rejected");

            using var form = new PresenterForm(folder, testMode: true);
            form.Show();
            form.Close();
            Check(!form.IsDisposed && !form.Visible, "Red close hides the window without disposing it");
            form.RestoreWindow();
            Check(form.Visible, "Hidden window can be restored");
            form.CleanAllFormatting();
            form.HideToTray();
            Check(File.Exists(Path.Combine(folder, "Autosave.ppdoc")), "Hiding saves the document");
        }
        finally { Directory.Delete(folder, recursive: true); }
        Console.WriteLine("Private Presenter Windows self-tests passed.");
    }

    private static void Check(bool condition, string description)
    {
        if (!condition) throw new InvalidOperationException("FAILED: " + description);
        Console.WriteLine("PASS: " + description);
    }
}
