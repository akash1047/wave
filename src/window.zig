const glfw = @import("glfw");

pub const Error = error{
    GlfwInitializationFailed,
    GlfwWindowCreationFailed,
};

pub const Window = struct {
    window: *glfw.GLFWwindow,

    pub fn new() !Window {
        if (glfw.glfwInit() != glfw.GLFW_TRUE) {
            return Error.GlfwInitializationFailed;
        }

        const window = glfw.glfwCreateWindow(960, 540, "Wave", null, null) orelse return Error.GlfwWindowCreationFailed;

        return Window{ .window = window };
    }

    pub fn run(self: *const Window) void {
        glfw.glfwMakeContextCurrent(self.window);
        while (glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_FALSE) {
            glfw.glfwSwapBuffers(self.window);
            glfw.glfwPollEvents();
        }
    }

    pub fn deinit(self: *const Window) void {
        glfw.glfwDestroyWindow(self.window);
        glfw.glfwTerminate();
    }
};
