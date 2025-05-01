#include "QuadShader.h"

#include "GL/glew.h"
#include "GLFW/glfw3.h"



QuadShader::QuadShader(const char* vertexPath, const char* fragmentPath) {



    // 1. retrieve the vertex/fragment source code from filePath
    std::string vertexCode;
    std::string fragmentCode;
    std::ifstream vShaderFile;
    std::ifstream fShaderFile;
    // ensure ifstream objects can throw exceptions:
    vShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    fShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    try
    {
        // open files
        vShaderFile.open(vertexPath);
        fShaderFile.open(fragmentPath);
        std::stringstream vShaderStream, fShaderStream;
        // read file's buffer contents into streams
        vShaderStream << vShaderFile.rdbuf();
        fShaderStream << fShaderFile.rdbuf();
        // close file handlers
        vShaderFile.close();
        fShaderFile.close();
        // convert stream into string
        vertexCode = vShaderStream.str();
        fragmentCode = fShaderStream.str();
    }
    catch (std::ifstream::failure& e)
    {
        std::cout << "ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ: " << e.what() << std::endl;
    }
    const char* vShaderCode = vertexCode.c_str();
    const char* fShaderCode = fragmentCode.c_str();
    // 2. compile shaders
    unsigned int vertex, fragment;
    // vertex shader
    vertex = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertex, 1, &vShaderCode, NULL);
    glCompileShader(vertex);
    
    // fragment Shader
    fragment = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragment, 1, &fShaderCode, NULL);
    glCompileShader(fragment);
    
    // shader Program
    ID = glCreateProgram();
    glAttachShader(ID, vertex);
    glAttachShader(ID, fragment);
    glLinkProgram(ID);
    
    // delete the shaders as they're linked into our program now and no longer necessary
    glDeleteShader(vertex);
    glDeleteShader(fragment);


    //// 1. retrieve the vertex/fragment source code from filePath
    //std::string vertexCode;
    //std::string fragmentCode;
    //std::ifstream vShaderFile(vertexPath);
    //std::ifstream fShaderFile(fragmentPath);
    //
    //std::string line;

    //while (getline(vShaderFile, line)) {

    //    vertexCode += line;
    //    printf(line.c_str());

    //}

    //while (getline(fShaderFile, line)) {

    //    fragmentCode += line;
    //    printf(line.c_str());

    //}


    //const char* vShaderCode = vertexCode.c_str();
    //const char* fShaderCode = fragmentCode.c_str();
    //// 2. compile shaders
    //unsigned int vertex, fragment;
    //// vertex shader
    //vertex = glCreateShader(GL_VERTEX_SHADER);
    //glShaderSource(vertex, 1, &vShaderCode, NULL);
    //glCompileShader(vertex);
    //
    //// fragment Shader
    //fragment = glCreateShader(GL_FRAGMENT_SHADER);
    //glShaderSource(fragment, 1, &fShaderCode, NULL);
    //glCompileShader(fragment);
    //
    //// shader Program
    //ID = glCreateProgram();
    //glAttachShader(ID, vertex);
    //glAttachShader(ID, fragment);
    //glLinkProgram(ID);
    //
    //// delete the shaders as they're linked into our program now and no longer necessary
    //glDeleteShader(vertex);
    //glDeleteShader(fragment);

}

void QuadShader::Use() const{
    
    glUseProgram(ID);
    

}

void QuadShader::SetInt(const std::string& name, int value) const {

    glUniform1i(glGetUniformLocation(ID, name.c_str()), value);

}
