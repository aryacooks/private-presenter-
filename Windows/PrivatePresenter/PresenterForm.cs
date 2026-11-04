namespace PrivatePresenter;

internal sealed class PresenterForm : Form
{
    private PresenterDocument document = new();
    private readonly FlowLayoutPanel pagesPanel = new() { Dock = DockStyle.Fill, AutoScroll = true, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = Color.White };
    private readonly ListBox pageList = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    private readonly List<RichTextBox> editors = [];
    private readonly Label status = new() { AutoSize = true, Text = "Ready", Margin = new Padding(12, 10, 0, 0) };
    private readonly NotifyIcon tray;
    private readonly System.Windows.Forms.Timer autosave = new() { Interval = 600 };
    private readonly string autosavePath;
    private string? documentPath;
    private bool rebuilding;
    private bool selecting;
    private bool quitting;
    private float zoom = 1;
    private bool excludeCapture = true;

    internal PresenterForm(string? storageFolder = null, bool testMode = false)
    {
        Text = "Private Presenter";
        ClientSize = new Size(1060, 720);
        MinimumSize = new Size(820, 480);
        StartPosition = FormStartPosition.CenterScreen;
        TopMost = true;
        Font = new Font("Segoe UI", 10);
        Icon = SystemIcons.Application;
        autosavePath = Path.Combine(storageFolder ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Private Presenter"), "Autosave.ppdoc");

        var header = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(8), WrapContents = true };
        AddButton(header, "Open…", OpenDocument);
        AddButton(header, "Save", () => SaveDocument(false));
        AddButton(header, "Save As…", () => SaveDocument(true));
        AddButton(header, "Add Page", AddPage);
        AddButton(header, "Paste into Page", PasteIntoPage);
        AddButton(header, "Clean All Formatting", CleanAllFormatting);
        AddButton(header, "Clear All…", ConfirmClearAll);

        var formatting = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(8, 0, 8, 8) };
        AddButton(formatting, "Bold", () => ToggleStyle(FontStyle.Bold));
        AddButton(formatting, "Italic", () => ToggleStyle(FontStyle.Italic));
        AddButton(formatting, "Underline", () => ToggleStyle(FontStyle.Underline));
        AddButton(formatting, "A−", () => ResizeText(-2));
        AddButton(formatting, "A+", () => ResizeText(2));
        AddButton(formatting, "Left", () => Align(HorizontalAlignment.Left));
        AddButton(formatting, "Centre", () => Align(HorizontalAlignment.Center));
        AddButton(formatting, "Right", () => Align(HorizontalAlignment.Right));

        var sidebar = new Panel { Dock = DockStyle.Right, Width = 190, Padding = new Padding(8) };
        var pageActions = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, FlowDirection = FlowDirection.TopDown, WrapContents = false };
        AddButton(pageActions, "Duplicate Page", DuplicatePage);
        AddButton(pageActions, "Clear Page Text", ClearPage);
        AddButton(pageActions, "Delete Page", DeletePage);
        sidebar.Controls.Add(pageList);
        sidebar.Controls.Add(pageActions);
        var pageMenu = new ContextMenuStrip();
        AddMenu(pageMenu, "Duplicate Page", DuplicatePage);
        AddMenu(pageMenu, "Clear Page Text", ClearPage);
        AddMenu(pageMenu, "Delete Page", DeletePage);
        pageList.ContextMenuStrip = pageMenu;
        pageList.MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Right)
            {
                int index = pageList.IndexFromPoint(e.Location);
                if (index >= 0) pageList.SelectedIndex = index;
            }
        };
        pageList.SelectedIndexChanged += (_, _) =>
        {
            if (rebuilding || selecting || pageList.SelectedIndex < 0) return;
            document.CurrentPage = pageList.SelectedIndex;
            pagesPanel.ScrollControlIntoView(editors[document.CurrentPage]);
            editors[document.CurrentPage].Focus();
            ScheduleAutosave();
        };
        pagesPanel.ClientSizeChanged += (_, _) => ResizeEditors();

        var footer = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, Padding = new Padding(8) };
        footer.Controls.Add(new Label { Text = "Zoom", AutoSize = true, Margin = new Padding(0, 10, 0, 0) });
        var zoomControl = new TrackBar { Minimum = 70, Maximum = 170, Value = 100, TickFrequency = 25, Width = 115, Height = 32, AutoSize = false };
        zoomControl.ValueChanged += (_, _) =>
        {
            zoom = zoomControl.Value / 100f;
            foreach (var editor in editors) editor.ZoomFactor = zoom;
        };
        footer.Controls.Add(zoomControl);
        footer.Controls.Add(new Label { Text = "Opacity", AutoSize = true, Margin = new Padding(8, 10, 0, 0) });
        var opacityControl = new TrackBar { Minimum = 35, Maximum = 100, Value = 100, Width = 100, Height = 32, AutoSize = false, TickFrequency = 25 };
        opacityControl.ValueChanged += (_, _) => Opacity = opacityControl.Value / 100d;
        footer.Controls.Add(opacityControl);
        var topmost = new CheckBox { Text = "Always on top", Checked = true, AutoSize = true, Margin = new Padding(8) };
        topmost.CheckedChanged += (_, _) => TopMost = topmost.Checked;
        footer.Controls.Add(topmost);
        var capture = new CheckBox { Text = "Exclude from capture", Checked = true, AutoSize = true, Margin = new Padding(8) };
        capture.CheckedChanged += (_, _) => { excludeCapture = capture.Checked; ApplyCaptureExclusion(); };
        footer.Controls.Add(capture);
        footer.Controls.Add(status);

        Controls.Add(pagesPanel);
        Controls.Add(sidebar);
        Controls.Add(formatting);
        Controls.Add(header);
        Controls.Add(footer);

        var trayMenu = new ContextMenuStrip();
        AddMenu(trayMenu, "Show Private Presenter", RestoreWindow);
        AddMenu(trayMenu, "Hide Window", HideToTray);
        trayMenu.Items.Add(new ToolStripSeparator());
        AddMenu(trayMenu, "Open Document…", () => { RestoreWindow(); OpenDocument(); });
        AddMenu(trayMenu, "Save", () => { RestoreWindow(); SaveDocument(false); });
        AddMenu(trayMenu, "Add Page", AddPage);
        AddMenu(trayMenu, "Duplicate Page", DuplicatePage);
        AddMenu(trayMenu, "Delete Page", DeletePage);
        AddMenu(trayMenu, "Clean All Formatting", CleanAllFormatting);
        AddMenu(trayMenu, "Clear All…", () => { RestoreWindow(); ConfirmClearAll(); });
        trayMenu.Items.Add(new ToolStripSeparator());
        AddMenu(trayMenu, "Quit Private Presenter", () => { quitting = true; Close(); });
        tray = new NotifyIcon { Text = "Private Presenter", Icon = SystemIcons.Application, ContextMenuStrip = trayMenu, Visible = !testMode };
        tray.DoubleClick += (_, _) => RestoreWindow();
        autosave.Tick += (_, _) => { autosave.Stop(); Run(SaveAutosave); };
        if (!testMode && File.Exists(autosavePath))
        {
            try { document = DocumentStore.Load(autosavePath); status.Text = "Restored last document"; }
            catch (Exception error) { status.Text = "Autosave could not be restored"; MessageBox.Show(this, error.Message, "Restore failed"); }
        }
        BuildEditors();
    }

    private void Run(Action action)
    {
        try { action(); }
        catch (Exception error) { MessageBox.Show(this, error.Message, "Private Presenter", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }

    private void AddButton(FlowLayoutPanel panel, string label, Action action)
    {
        var button = new Button { Text = label, AutoSize = true, Padding = new Padding(4), TabStop = true };
        button.Click += (_, _) => Run(action);
        panel.Controls.Add(button);
    }

    private void AddMenu(ContextMenuStrip menu, string label, Action action)
    {
        menu.Items.Add(label, null, (_, _) => Run(action));
    }

    private RichTextBox ActiveEditor => editors[document.CurrentPage];

    private void BuildEditors()
    {
        rebuilding = true;
        pagesPanel.SuspendLayout();
        try
        {
            foreach (var editor in editors) editor.Dispose();
            editors.Clear();
            pagesPanel.Controls.Clear();
            for (int i = 0; i < document.Pages.Count; i++)
            {
                int index = i;
                var editor = new RichTextBox
                {
                    BorderStyle = BorderStyle.None, BackColor = Color.White, ForeColor = Color.Black,
                    Font = new Font("Segoe UI", 22), DetectUrls = false, AcceptsTab = true,
                    ScrollBars = RichTextBoxScrollBars.None, WordWrap = true, Margin = new Padding(18, 8, 18, 8),
                    Width = Math.Max(100, pagesPanel.ClientSize.Width - 60), Height = 120,
                    Rtf = document.Pages[i], ZoomFactor = zoom
                };
                editor.ContentsResized += (_, e) => editor.Height = Math.Max(80, e.NewRectangle.Height + 30);
                editor.Enter += (_, _) =>
                {
                    document.CurrentPage = index;
                    SelectSidebar(index);
                };
                editor.TextChanged += (_, _) =>
                {
                    if (rebuilding) return;
                    document.Pages[index] = editor.Rtf ?? PresenterDocument.BlankRtf;
                    pageList.Items[index] = Preview(index, editor.Text);
                    ScheduleAutosave();
                };
                editors.Add(editor);
                pagesPanel.Controls.Add(editor);
                // Trigger rich-edit layout after event handlers are connected.
                editor.Rtf = document.Pages[i];
            }
            pageList.Items.Clear();
            for (int i = 0; i < editors.Count; i++) pageList.Items.Add(Preview(i, editors[i].Text));
            SelectSidebar(document.CurrentPage);
            Text = $"{document.Name} — Private Presenter";
        }
        finally { rebuilding = false; pagesPanel.ResumeLayout(true); }
        ResizeEditors();
        pagesPanel.ScrollControlIntoView(ActiveEditor);
    }

    private static string Preview(int index, string text)
    {
        string preview = text.Replace('\r', ' ').Replace('\n', ' ').Trim();
        return $"{index + 1}. {(preview.Length == 0 ? "Blank page" : preview[..Math.Min(36, preview.Length)])}";
    }

    private void SelectSidebar(int index)
    {
        selecting = true;
        try { pageList.SelectedIndex = index; }
        finally { selecting = false; }
    }

    private void ResizeEditors()
    {
        foreach (var editor in editors) editor.Width = Math.Max(100, pagesPanel.ClientSize.Width - 60);
    }

    private void ScheduleAutosave() { autosave.Stop(); autosave.Start(); }
    private void CaptureEdits()
    {
        for (int i = 0; i < editors.Count; i++) document.Pages[i] = editors[i].Rtf ?? PresenterDocument.BlankRtf;
    }
    private void SaveAutosave() { CaptureEdits(); DocumentStore.Save(document, autosavePath); }
    private void ChangedPages(string message) { BuildEditors(); ScheduleAutosave(); status.Text = message; }
    private void AddPage() { document.Add(); ChangedPages("Added page"); }
    private void DuplicatePage() { CaptureEdits(); document.Duplicate(document.CurrentPage); ChangedPages("Duplicated page"); }
    private void DeletePage() { document.Delete(document.CurrentPage); ChangedPages("Deleted page"); }
    private void ClearPage() { document.Pages[document.CurrentPage] = PresenterDocument.BlankRtf; ChangedPages("Cleared page"); }

    private void ConfirmClearAll()
    {
        if (MessageBox.Show(this, "Remove every page and leave one blank page? Save a copy first to keep this document.", "Clear all pages?",
            MessageBoxButtons.OKCancel, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.OK) return;
        document.Clear();
        ChangedPages("Cleared all pages");
    }

    internal void CleanAllFormatting()
    {
        for (int i = 0; i < document.Pages.Count; i++)
        {
            using var clean = new RichTextBox { Font = new Font("Segoe UI", 22), ForeColor = Color.Black, BackColor = Color.White, Text = editors[i].Text };
            document.Pages[i] = clean.Rtf ?? PresenterDocument.BlankRtf;
        }
        ChangedPages("Clean formatting applied to all pages");
    }

    private void PasteIntoPage()
    {
        var editor = ActiveEditor;
        editor.Select(editor.TextLength, 0);
        if (editor.TextLength > 0 && !editor.Text.EndsWith('\n')) editor.SelectedText = "\n";
        editor.Paste();
        editor.Focus();
    }

    private void ToggleStyle(FontStyle style)
    {
        var editor = ActiveEditor;
        var current = editor.SelectionFont ?? editor.Font;
        using var font = new Font(current, current.Style ^ style);
        editor.SelectionFont = font;
        ScheduleAutosave();
        editor.Focus();
    }

    private void ResizeText(float delta)
    {
        var editor = ActiveEditor;
        var font = editor.SelectionFont ?? editor.Font;
        using var replacement = new Font(font.FontFamily, Math.Max(6, font.Size + delta), font.Style);
        editor.SelectionFont = replacement;
        ScheduleAutosave();
        editor.Focus();
    }

    private void Align(HorizontalAlignment alignment) { ActiveEditor.SelectionAlignment = alignment; ScheduleAutosave(); ActiveEditor.Focus(); }

    private void OpenDocument()
    {
        using var picker = new OpenFileDialog { Filter = "Presenter documents|*.ppdoc|Rich text|*.rtf|Text|*.txt;*.md", CheckFileExists = true };
        if (picker.ShowDialog(this) != DialogResult.OK) return;
        PresenterDocument loaded;
        bool project = Path.GetExtension(picker.FileName).Equals(".ppdoc", StringComparison.OrdinalIgnoreCase);
        if (project) loaded = DocumentStore.Load(picker.FileName);
        else
        {
            using var editor = new RichTextBox { Font = new Font("Segoe UI", 22) };
            if (Path.GetExtension(picker.FileName).Equals(".rtf", StringComparison.OrdinalIgnoreCase)) editor.LoadFile(picker.FileName, RichTextBoxStreamType.RichText);
            else editor.Text = File.ReadAllText(picker.FileName);
            loaded = new PresenterDocument { Name = Path.GetFileNameWithoutExtension(picker.FileName), Pages = [editor.Rtf ?? PresenterDocument.BlankRtf] };
        }
        SaveAutosave();
        document = loaded;
        documentPath = project ? picker.FileName : null;
        ChangedPages("Opened document");
    }

    private void SaveDocument(bool saveAs)
    {
        CaptureEdits();
        string? path = saveAs ? null : documentPath;
        if (path is null)
        {
            using var picker = new SaveFileDialog { Filter = "Presenter document|*.ppdoc", DefaultExt = "ppdoc", FileName = "Presenter Document.ppdoc" };
            if (picker.ShowDialog(this) != DialogResult.OK) return;
            path = picker.FileName;
        }
        var previousName = document.Name;
        document.Name = Path.GetFileNameWithoutExtension(path);
        try { DocumentStore.Save(document, path); }
        catch { document.Name = previousName; throw; }
        documentPath = path;
        Text = $"{document.Name} — Private Presenter";
        status.Text = "Saved document";
        ScheduleAutosave();
    }

    internal void HideToTray()
    {
        SaveAutosave();
        Hide();
    }

    internal void RestoreWindow()
    {
        Show();
        WindowState = FormWindowState.Normal;
        Activate();
    }

    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); ApplyCaptureExclusion(); }

    private void ApplyCaptureExclusion()
    {
        if (!IsHandleCreated) return;
        bool applied = NativeMethods.SetWindowDisplayAffinity(Handle, excludeCapture ? 0x11u : 0u);
        status.Text = applied ? (excludeCapture ? "Capture exclusion requested" : "Capture exclusion off") : "Capture exclusion unavailable";
    }

    protected override void WndProc(ref Message message)
    {
        if ((uint)message.Msg == NativeMethods.ShowMessage) { RestoreWindow(); return; }
        base.WndProc(ref message);
    }

    protected override bool ProcessCmdKey(ref Message message, Keys keyData)
    {
        Action? action = keyData switch
        {
            Keys.Control | Keys.S => () => SaveDocument(false),
            Keys.Control | Keys.Shift | Keys.S => () => SaveDocument(true),
            Keys.Control | Keys.O => OpenDocument,
            Keys.Control | Keys.Shift | Keys.N => AddPage,
            Keys.Control | Keys.B => () => ToggleStyle(FontStyle.Bold),
            Keys.Control | Keys.I => () => ToggleStyle(FontStyle.Italic),
            Keys.Control | Keys.U => () => ToggleStyle(FontStyle.Underline),
            Keys.Control | Keys.Q => () => { quitting = true; Close(); },
            _ => null
        };
        if (action is null) return base.ProcessCmdKey(ref message, keyData);
        Run(action);
        return true;
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (WindowState == FormWindowState.Minimized && tray is not null) Run(HideToTray);
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        try { autosave.Stop(); SaveAutosave(); }
        catch (Exception error)
        {
            if (e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                MessageBox.Show(this, error.Message, "Could not save document");
                return;
            }
        }
        if (!quitting && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); }
        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { autosave.Dispose(); tray?.Dispose(); }
        base.Dispose(disposing);
    }
}
