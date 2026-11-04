using System.Runtime.InteropServices;

namespace PrivatePresenter;

internal static class NativeMethods
{
    internal static readonly IntPtr HWND_BROADCAST = new(0xffff);
    internal static readonly uint ShowMessage = RegisterWindowMessage("Aryacooks.PrivatePresenter.Show.v1");

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowDisplayAffinity(IntPtr window, uint affinity);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern uint RegisterWindowMessage(string message);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
