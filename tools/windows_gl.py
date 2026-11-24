"""Minimal dependency-free, hidden WGL context for real driver shader checks."""
import ctypes as c
from ctypes import wintypes as w
import re


class PixelFormat(c.Structure):
    _fields_ = [("size", w.WORD), ("version", w.WORD), ("flags", w.DWORD),
                ("pixelType", c.c_ubyte), ("colorBits", c.c_ubyte),
                ("redBits", c.c_ubyte), ("redShift", c.c_ubyte),
                ("greenBits", c.c_ubyte), ("greenShift", c.c_ubyte),
                ("blueBits", c.c_ubyte), ("blueShift", c.c_ubyte),
                ("alphaBits", c.c_ubyte), ("alphaShift", c.c_ubyte),
                ("accumBits", c.c_ubyte), ("accumRedBits", c.c_ubyte),
                ("accumGreenBits", c.c_ubyte), ("accumBlueBits", c.c_ubyte),
                ("accumAlphaBits", c.c_ubyte), ("depthBits", c.c_ubyte),
                ("stencilBits", c.c_ubyte), ("auxBuffers", c.c_ubyte),
                ("layerType", c.c_ubyte), ("reserved", c.c_ubyte),
                ("layerMask", w.DWORD), ("visibleMask", w.DWORD), ("damageMask", w.DWORD)]


class WindowsGL:
    def __init__(self):
        self.user = c.WinDLL("user32", use_last_error=True)
        self.gdi = c.WinDLL("gdi32", use_last_error=True)
        self.gl = c.WinDLL("opengl32", use_last_error=True)
        self.user.CreateWindowExW.restype = w.HWND
        self.user.CreateWindowExW.argtypes = [w.DWORD, w.LPCWSTR, w.LPCWSTR, w.DWORD,
            c.c_int, c.c_int, c.c_int, c.c_int, w.HWND, w.HMENU, w.HINSTANCE, w.LPVOID]
        # No WS_VISIBLE: this context never opens an interactive window.
        self.window = self.user.CreateWindowExW(0, "STATIC", "AeroDream GLSL validation", 0,
                                               0, 0, 1, 1, None, None, None, None)
        if not self.window:
            raise c.WinError(c.get_last_error())
        self.user.GetDC.argtypes = [w.HWND]
        self.user.GetDC.restype = w.HDC
        self.dc = self.user.GetDC(self.window)
        descriptor = PixelFormat()
        descriptor.size = c.sizeof(PixelFormat)
        descriptor.version = 1
        descriptor.flags = 0x4 | 0x20  # draw to window, support OpenGL
        descriptor.colorBits = 24
        descriptor.depthBits = 24
        self.gdi.ChoosePixelFormat.argtypes = [w.HDC, c.POINTER(PixelFormat)]
        self.gdi.SetPixelFormat.argtypes = [w.HDC, c.c_int, c.POINTER(PixelFormat)]
        chosen = self.gdi.ChoosePixelFormat(self.dc, c.byref(descriptor))
        if not chosen or not self.gdi.SetPixelFormat(self.dc, chosen, c.byref(descriptor)):
            raise c.WinError(c.get_last_error())
        self.gl.wglCreateContext.argtypes = [w.HDC]
        self.gl.wglCreateContext.restype = w.HANDLE
        self.context = self.gl.wglCreateContext(self.dc)
        self.gl.wglMakeCurrent.argtypes = [w.HDC, w.HANDLE]
        if not self.context or not self.gl.wglMakeCurrent(self.dc, self.context):
            raise RuntimeError("Cannot create a hidden OpenGL context")
        self.gl.glGetString.argtypes = [c.c_uint]
        self.gl.glGetString.restype = c.c_char_p
        print("OpenGL driver: " + self.gl.glGetString(0x1F02).decode(), flush=True)
        print("OpenGL renderer: " + self.gl.glGetString(0x1F01).decode(), flush=True)
        self.gl.wglGetProcAddress.argtypes = [c.c_char_p]
        self.gl.wglGetProcAddress.restype = c.c_void_p
        self.create_shader = self.function("glCreateShader", c.c_uint, c.c_uint)
        self.shader_source = self.function("glShaderSource", None, c.c_uint, c.c_int, c.POINTER(c.c_char_p), c.POINTER(c.c_int))
        self.compile_shader = self.function("glCompileShader", None, c.c_uint)
        self.get_shader = self.function("glGetShaderiv", None, c.c_uint, c.c_uint, c.POINTER(c.c_int))
        self.shader_log = self.function("glGetShaderInfoLog", None, c.c_uint, c.c_int, c.POINTER(c.c_int), c.c_char_p)
        self.create_program = self.function("glCreateProgram", c.c_uint)
        self.attach_shader = self.function("glAttachShader", None, c.c_uint, c.c_uint)
        self.link_program = self.function("glLinkProgram", None, c.c_uint)
        self.get_program = self.function("glGetProgramiv", None, c.c_uint, c.c_uint, c.POINTER(c.c_int))
        self.program_log = self.function("glGetProgramInfoLog", None, c.c_uint, c.c_int, c.POINTER(c.c_int), c.c_char_p)
        self.delete_program = self.function("glDeleteProgram", None, c.c_uint)
        self.cache = {}

    def function(self, name, result, *args):
        pointer = self.gl.wglGetProcAddress(name.encode())
        if not pointer or pointer in (1, 2, 3, c.c_void_p(-1).value):
            pointer = c.cast(getattr(self.gl, name, None), c.c_void_p).value
            if not pointer:
                raise RuntimeError(f"OpenGL driver does not provide {name}; use glslangValidator")
        return c.WINFUNCTYPE(result, *args)(pointer)

    def shader(self, source, kind, label):
        key = (source, kind)
        if key in self.cache:
            return self.cache[key]
        shader = self.create_shader(kind)
        encoded = c.c_char_p(source.encode())
        self.shader_source(shader, 1, c.byref(encoded), None)
        self.compile_shader(shader)
        status = c.c_int()
        self.get_shader(shader, 0x8B81, c.byref(status))
        if not status.value:
            log = c.create_string_buffer(32768)
            self.shader_log(shader, len(log), None, log)
            lines = source.splitlines()
            error_lines = {int(n) for n in re.findall(r"0:(\d+)", log.value.decode())}
            numbered = "\n".join(f"{n}: {line}" for n, line in enumerate(lines, 1)
                                   if any(abs(n - error) <= 3 for error in error_lines))
            raise RuntimeError(f"{label}\n{log.value.decode()}\n{numbered}")
        self.cache[key] = shader
        return shader

    def link(self, vertex, fragment, label):
        program = self.create_program()
        self.attach_shader(program, self.shader(vertex, 0x8B31, label + " vertex"))
        self.attach_shader(program, self.shader(fragment, 0x8B30, label + " fragment"))
        self.link_program(program)
        status = c.c_int()
        self.get_program(program, 0x8B82, c.byref(status))
        if not status.value:
            log = c.create_string_buffer(32768)
            self.program_log(program, len(log), None, log)
            raise RuntimeError(f"{label}\n{log.value.decode()}")
        self.delete_program(program)
