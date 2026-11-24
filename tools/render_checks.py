"""Offscreen numeric GLSL checks, independent of Minecraft and visual benchmarks."""
import ctypes as c
import math

from validate import SHADERS, expand
from windows_gl import WindowsGL


class Probes:
    def __init__(self):
        self.gl = WindowsGL()
        f = self.gl.function
        self.gen_textures = f("glGenTextures", None, c.c_int, c.POINTER(c.c_uint))
        self.bind_texture = f("glBindTexture", None, c.c_uint, c.c_uint)
        self.active_texture = f("glActiveTexture", None, c.c_uint)
        self.tex_image = f("glTexImage2D", None, c.c_uint, c.c_int, c.c_int, c.c_int, c.c_int, c.c_int, c.c_uint, c.c_uint, c.c_void_p)
        self.tex_parameter = f("glTexParameteri", None, c.c_uint, c.c_uint, c.c_int)
        self.gen_fbos = f("glGenFramebuffers", None, c.c_int, c.POINTER(c.c_uint))
        self.bind_fbo = f("glBindFramebuffer", None, c.c_uint, c.c_uint)
        self.attach_texture = f("glFramebufferTexture2D", None, c.c_uint, c.c_uint, c.c_uint, c.c_uint, c.c_int)
        self.check_fbo = f("glCheckFramebufferStatus", c.c_uint, c.c_uint)
        self.use_program = f("glUseProgram", None, c.c_uint)
        self.location = f("glGetUniformLocation", c.c_int, c.c_uint, c.c_char_p)
        self.uniform_i = f("glUniform1i", None, c.c_int, c.c_int)
        self.uniform_f = f("glUniform1f", None, c.c_int, c.c_float)
        self.uniform_3f = f("glUniform3f", None, c.c_int, c.c_float, c.c_float, c.c_float)
        self.uniform_matrix = f("glUniformMatrix4fv", None, c.c_int, c.c_int, c.c_ubyte, c.POINTER(c.c_float))
        self.viewport = f("glViewport", None, c.c_int, c.c_int, c.c_int, c.c_int)
        self.begin = f("glBegin", None, c.c_uint)
        self.vertex = f("glVertex2f", None, c.c_float, c.c_float)
        self.end = f("glEnd", None)
        self.read_pixels = f("glReadPixels", None, c.c_int, c.c_int, c.c_int, c.c_int, c.c_uint, c.c_uint, c.c_void_p)
        self.target = self.texture((0, 0, 0, 0))
        framebuffer = c.c_uint()
        self.gen_fbos(1, c.byref(framebuffer))
        self.bind_fbo(0x8D40, framebuffer.value)
        self.attach_texture(0x8D40, 0x8CE0, 0x0DE1, self.target, 0)
        if self.check_fbo(0x8D40) != 0x8CD5:
            raise RuntimeError("Offscreen floating-point framebuffer is incomplete")
        self.viewport(0, 0, 1, 1)

    def texture(self, rgba):
        texture = c.c_uint()
        self.gen_textures(1, c.byref(texture))
        self.bind_texture(0x0DE1, texture.value)
        pixels = (c.c_float * 4)(*rgba)
        self.tex_image(0x0DE1, 0, 0x8814, 1, 1, 0, 0x1908, 0x1406, pixels)
        self.tex_parameter(0x0DE1, 0x2801, 0x2600)
        self.tex_parameter(0x0DE1, 0x2800, 0x2600)
        return texture.value

    def program(self, body, options=None, dimension=0, extra=(), preamble=""):
        libraries = expand(SHADERS / "lib/common.glsl", options or {})
        libraries += "\n" + preamble + "\n"
        for library in extra:
            libraries += expand(SHADERS / "lib" / library, options or {})
        fragment = f"#version 330 compatibility\n#define IS_IRIS\n#define AERO_DIMENSION {dimension}\n" + libraries
        fragment += "\nlayout(location=0) out vec4 probe;\nvoid main() {\n" + body + "\n}\n"
        vertex = "#version 330 compatibility\nvoid main() { gl_Position = gl_Vertex; }"
        program = self.gl.create_program()
        self.gl.attach_shader(program, self.gl.shader(vertex, 0x8B31, "probe vertex"))
        self.gl.attach_shader(program, self.gl.shader(fragment, 0x8B30, "probe fragment"))
        self.gl.link_program(program)
        status = c.c_int()
        self.gl.get_program(program, 0x8B82, c.byref(status))
        if not status.value:
            raise RuntimeError("Cannot link numeric probe")
        return program

    def render(self, program, uniforms=None, textures=None):
        self.use_program(program)
        defaults = {"hasSkylight": 1, "aeroTemperature": 0.8, "aeroRainfall": 0.5,
                    "aeroPrecipitation": 1.0, "gbufferModelViewInverse": identity(),
                    "sunPosition": (0.0, 1.0, 0.0), "fogColor": (0.18, 0.08, 0.04)}
        for name, value in (defaults | (uniforms or {})).items():
            location = self.location(program, name.encode())
            if isinstance(value, int):
                self.uniform_i(location, value)
            elif isinstance(value, float):
                self.uniform_f(location, value)
            elif len(value) == 16:
                self.uniform_matrix(location, 1, False, (c.c_float * 16)(*value))
            else:
                self.uniform_3f(location, *value)
        for unit, (name, rgba) in enumerate((textures or {}).items()):
            self.active_texture(0x84C0 + unit)
            self.texture(rgba)
            self.uniform_i(self.location(program, name.encode()), unit)
        self.begin(0x0004)
        self.vertex(-1.0, -1.0)
        self.vertex(3.0, -1.0)
        self.vertex(-1.0, 3.0)
        self.end()
        pixel = (c.c_float * 4)()
        self.read_pixels(0, 0, 1, 1, 0x1908, 0x1406, pixel)
        result = tuple(pixel)
        if not all(math.isfinite(value) for value in result):
            raise AssertionError(f"Non-finite GPU result: {result}")
        return result


def identity(scale=1.0):
    return (scale, 0.0, 0.0, 0.0, 0.0, scale, 0.0, 0.0,
            0.0, 0.0, scale, 0.0, 0.0, 0.0, 0.0, 1.0)


def main():
    probes = Probes()
    moon = probes.program("probe = vec4(aeroMoonDisk(vec3(0,0,-1), vec3(0,0,-1))); ")
    assert probes.render(moon, {"moonPhase": 0})[0] > 0.99
    assert probes.render(moon, {"moonPhase": 4})[0] < 0.001
    climate = probes.program("probe = vec4(aeroClimate(), aeroLocalRain());")
    assert probes.render(climate, {"aeroTemperature": -0.3, "aeroPrecipitation": 0.0})[3] == 0.0
    assert probes.render(climate, {"aeroTemperature": 1.8, "aeroRainfall": 0.0, "aeroPrecipitation": 0.0})[1] > 0.5
    assert probes.render(climate, {"aeroTemperature": 1.0, "aeroRainfall": 1.0})[2] > 0.5
    assert probes.render(climate, {"hasSkylight": 0}) == (0.0, 0.0, 0.0, 0.0)
    lamp = probes.program("probe = vec4(aeroHandLight(vec3(0,0,-2), vec3(0,0,1)), 1);", extra=("handlight.glsl",))
    empty = probes.render(lamp)
    main_light = probes.render(lamp, {"heldBlockLightValue": 15})
    off_light = probes.render(lamp, {"heldBlockLightValue2": 15})
    both = probes.render(lamp, {"heldBlockLightValue": 15, "heldBlockLightValue2": 15})
    assert empty[:3] == (0.0, 0.0, 0.0)
    assert main_light[0] > main_light[2] > 0.0
    assert all(abs(a - b) < 0.0001 for a, b in zip(main_light, off_light))
    assert all(abs(a - b) < 0.0001 for a, b in zip(main_light, both))
    rays = probes.program("probe = vec4(aeroUnderwaterRays(vec3(0,0,-1), 8.0, aeroSunDir()), 1);",
                          extra=("caustics.glsl", "underwater.glsl"))
    transforms = {"shadowProjection": identity(0.02), "shadowModelView": identity()}
    lit = probes.render(rays, transforms, {"shadowtex0": (1.0, 1.0, 1.0, 1.0)})
    dark = probes.render(rays, transforms, {"shadowtex0": (0.0, 0.0, 0.0, 0.0)})
    night = probes.render(rays, transforms | {"sunPosition": (0.0, -1.0, 0.0)}, {"shadowtex0": (1.0, 1.0, 1.0, 1.0)})
    assert lit[1] > 0.0 and dark[:3] == (0.0, 0.0, 0.0) and night[:3] == (0.0, 0.0, 0.0)
    material = probes.program(
        "AeroMaterial m = aeroReadMaterial(vec2(0.5), vec3(gl_FragCoord.xy, 0), vec3(0,0,1), vec3(0.8,0.5,0.2));\n"
        "probe = vec4(m.smoothness, m.metal, m.emission, m.ao);",
        options={"MATERIAL_MAPS": "2"}, extra=("materials.glsl",))
    mapped = probes.render(material, textures={"normals": (0.5, 0.5, 0.75, 1.0), "specular": (0.8, 1.0, 0.0, 1.0)})
    assert abs(mapped[0] - 0.8) < 0.001 and mapped[1] == 1.0 and mapped[2] == 0.0
    assert abs(mapped[3] - 0.75) < 0.001
    for dimension in (-1, 1):
        sky = probes.program("probe = vec4(aeroSky(vec3(0,0.3,-1), aeroSunDir(), 0.0), aeroOverworld());", dimension=dimension)
        result = probes.render(sky)
        assert result[3] == 0.0 and max(result[:3]) > 0.01
    glass = probes.program("probe = vec4(aeroShadowSample(vec3(0.5), 0.0), 1);", extra=("shadows.glsl",))
    blue_glass = {"shadowtex0": (0.25, 0, 0, 0), "shadowtex1": (0.75, 0, 0, 0),
                  "shadowcolor0": (0.15, 0.5, 0.9, 1.0)}
    tinted = probes.render(glass, textures=blue_glass)
    assert all(abs(a-b) < 0.001 for a,b in zip(tinted[:3], (0.15, 0.5, 0.9)))
    blocked = probes.render(glass, textures=blue_glass | {"shadowtex1": (0.25, 0, 0, 0)})
    assert blocked[:3] == (0.0, 0.0, 0.0)
    unblocked = probes.render(glass, textures=blue_glass | {"shadowtex0": (0.75, 0, 0, 0)})
    assert unblocked[:3] == (1.0, 1.0, 1.0)
    waves = probes.program(
        "vec2 p=vec2(3.1,4.7); float t=2.3; vec2 g=aeroSurfaceGradient(p,t,0.8);"
        "float dx=(aeroSurfaceHeight(p+vec2(0.001,0),t,0.8)-aeroSurfaceHeight(p-vec2(0.001,0),t,0.8))/0.002;"
        "float dy=(aeroSurfaceHeight(p+vec2(0,0.001),t,0.8)-aeroSurfaceHeight(p-vec2(0,0.001),t,0.8))/0.002;"
        "probe=vec4(aeroSurfaceHeight(p,t,0.8),g.x-dx,g.y-dy,1);", extra=("watermotion.glsl",))
    wave = probes.render(waves)
    assert abs(wave[0]) > 0.0001 and abs(wave[1]) < 0.0001 and abs(wave[2]) < 0.0001
    still = probes.program("probe=vec4(aeroSurfaceHeight(vec2(3.1),2.0,1.0));",
                           options={"WATER_SURFACE_MOTION": "0.00"}, extra=("watermotion.glsl",))
    assert probes.render(still) == (0.0, 0.0, 0.0, 0.0)
    history = probes.program(
        "probe=vec4(aeroHistoryConfidence(vec4(1,1,1,5),5), aeroHistoryConfidence(vec4(0),5),"
        "aeroHistoryConfidence(vec4(1,1,1,10),5), aeroHistoryConfidence(vec4(1,1,1,-1),-1));",
        extra=("temporal.glsl",))
    assert probes.render(history) == (1.0, 0.0, 0.0, 1.0)
    jitter = probes.program("vec2 total=vec2(0); for(int i=0;i<8;i++) total+=aeroJitter(i,vec2(1920,1080)); probe=vec4(total,0,1);",
                            options={"TAA_ENABLED": "1"})
    assert max(abs(x) for x in probes.render(jitter)[:2]) < 0.000001
    clouds = probes.program(
        "float maximum=0; for(int i=0;i<24;i++) maximum=max(maximum,aeroCloudDensity3(vec3(float(i)*23,205,float(i)*13),0));"
        "probe=vec4(aeroCloudDensity3(vec3(0,150,0),0), aeroCloudDensity3(vec3(0,250,0),0),maximum,1);",
        options={"CLOUD_MODE": "1"})
    cloud = probes.render(clouds)
    assert cloud[0] == 0.0 and cloud[1] == 0.0 and 0.0 < cloud[2] < 0.066
    photo = probes.program("probe=vec4(aeroCircleOfConfusion(8,8),aeroCircleOfConfusion(2,8),aeroCircleOfConfusion(1000,8),1);",
                           extra=("photo.glsl",))
    blur = probes.render(photo)
    assert blur[0] == 0.0 and blur[1] > 0.0 and blur[2] > 0.0
    local_light = probes.program("probe=vec4(aeroColoredBlockLight(vec2(0.5),vec3(0,0,-0.8),vec3(0,0,1)),1);",
        extra=("reflections.glsl", "coloredlight.glsl"),
        preamble="uniform sampler2D depthtex0; uniform mat4 gbufferProjection; uniform mat4 gbufferProjectionInverse; uniform mat4 gbufferModelView;")
    light_uniforms={"viewWidth": 1920.0, "viewHeight": 1080.0, "gbufferProjection": identity(),
                    "gbufferProjectionInverse": identity(), "gbufferModelView": identity()}
    local = probes.render(local_light, light_uniforms, {"colortex2": (0,0,1,1), "depthtex0": (0.1,0,0,0)})
    assert local[0] == 0.0 and local[1] == 0.0 and local[2] > 0.0
    print("Offscreen GPU checks passed: prior features, glass transmission/occlusion, wave gradients, temporal rejection/jitter, cloud density, focus blur and local light color")


if __name__ == "__main__":
    main()
