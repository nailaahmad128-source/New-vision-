#include <windows.h>
#include <memory>
#include <optional>

#include "flutter/dart_project.h"
#include "flutter/flutter_view_controller.h"
#include "flutter/generated_plugin_registrant.h"

namespace {
std::unique_ptr<flutter::FlutterViewController> g_controller;

LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (g_controller) {
    std::optional<LRESULT> handled =
        g_controller->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (handled) return *handled;
  }

  switch (message) {
    case WM_SIZE:
      if (g_controller && g_controller->view()) {
        HWND view = g_controller->view()->GetNativeWindow();
        RECT r{};
        GetClientRect(hwnd, &r);
        SetWindowPos(view, nullptr, 0, 0, r.right - r.left, r.bottom - r.top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
      }
      return 0;
    case WM_DESTROY:
      g_controller.reset();
      PostQuitMessage(0);
      return 0;
    default:
      return DefWindowProc(hwnd, message, wparam, lparam);
  }
}
}  // namespace

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE, wchar_t*, int show_command) {
  const wchar_t kClassName[] = L"PDFMasterToolsFlutterWindow";

  WNDCLASS wc{};
  wc.lpfnWndProc = WindowProc;
  wc.hInstance = instance;
  wc.lpszClassName = kClassName;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  RegisterClass(&wc);

  HWND window = CreateWindowEx(
      0, kClassName, L"PDF Master Tools", WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT, CW_USEDEFAULT, 1280, 820, nullptr, nullptr, instance, nullptr);
  if (!window) return 1;

  flutter::DartProject project(L"data");
  g_controller = std::make_unique<flutter::FlutterViewController>(
      1280, 820, project);
  if (!g_controller || !g_controller->engine() || !g_controller->view()) return 1;

  RegisterPlugins(g_controller->engine());
  HWND view = g_controller->view()->GetNativeWindow();
  SetParent(view, window);
  LONG_PTR style = GetWindowLongPtr(view, GWL_STYLE);
  SetWindowLongPtr(view, GWL_STYLE, style | WS_CHILD | WS_VISIBLE);
  RECT client{};
  GetClientRect(window, &client);
  SetWindowPos(view, nullptr, 0, 0, client.right - client.left,
               client.bottom - client.top, SWP_NOZORDER | SWP_SHOWWINDOW);

  ShowWindow(window, show_command);
  UpdateWindow(window);

  MSG message;
  while (GetMessage(&message, nullptr, 0, 0)) {
    TranslateMessage(&message);
    DispatchMessage(&message);
  }
  return static_cast<int>(message.wParam);
}
