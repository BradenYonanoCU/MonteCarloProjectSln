#include "ComputeShader.h"

#include "GL/glew.h"
#include "GLFW/glfw3.h"



ComputeShader::ComputeShader(const char* computePath) {

    // 1. retrieve the vertex/fragment source code from filePath
    std::string computeCode;
    std::ifstream cShaderFile;
    // ensure ifstream objects can throw exceptions:
    cShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    try
    {
        // open files
        cShaderFile.open(computePath);

        std::stringstream cShaderStream;
        // read file's buffer contents into streams
        cShaderStream << cShaderFile.rdbuf();
        // close file handlers
        cShaderFile.close();
        // convert stream into string
        computeCode = cShaderStream.str();
    }
    catch (std::ifstream::failure& e)
    {
        std::cout << "ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ: " << e.what() << std::endl;
    }
    const char* cShaderCode = computeCode.c_str();
    // 2. compile shaders
    unsigned int compute;
    // compute shader
    compute = glCreateShader(GL_COMPUTE_SHADER);
    glShaderSource(compute, 1, &cShaderCode, NULL);
    glCompileShader(compute);
    

    // shader Program
    ID = glCreateProgram();
    glAttachShader(ID, compute);
    glLinkProgram(ID);
    
    // delete the shaders as they're linked into our program now and no longer necessary
    glDeleteShader(compute);


	/*
	std::ifstream fstream(computePath);

	std::string line;
	std::string full;

	const GLchar* cShaderCode;

	while (getline(fstream, line)) {

		full += line;
		printf(line.c_str());

	}

	cShaderCode = full.c_str();

	unsigned int compute;
	// compute shader
	compute = glCreateShader(GL_COMPUTE_SHADER);
	glShaderSource(compute, 1, &cShaderCode, NULL);
	glCompileShader(compute);
	//checkCompileErrors(compute, "COMPUTE");

	// shader Program
	ID = glCreateProgram();
	glAttachShader(ID, compute);
	glLinkProgram(ID);
	//checkCompileErrors(ID, "PROGRAM");
	*/
}

void ComputeShader::Use() {

	glUseProgram(ID);

}


void ComputeShader::SetFloat(const std::string& name, float value) const
{
	glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
}

void ComputeShader::SetInt(const std::string& name, int value) const {

    glUniform1i(glGetUniformLocation(ID, name.c_str()), value);

}