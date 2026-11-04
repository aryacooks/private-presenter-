namespace PrivatePresenter;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        if (args.Contains("--self-test"))
        {
            using var log = new StreamWriter(Path.Combine(AppContext.BaseDirectory, "self-test.log")) { AutoFlush = true };
            Console.SetOut(log);
            Console.SetError(log);
            try { SelfTests.Run(); return 0; }
            catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        }

        // A second launch restores the existing tray window instead of competing for autosave.
        using var mutex = new Mutex(true, @"Local\Aryacooks.PrivatePresenter", out bool firstInstance);
        if (!firstInstance)
        {
            NativeMethods.PostMessage(NativeMethods.HWND_BROADCAST, NativeMethods.ShowMessage, IntPtr.Zero, IntPtr.Zero);
            return 0;
        }
        Application.Run(new PresenterForm());
        return 0;
    }
}
