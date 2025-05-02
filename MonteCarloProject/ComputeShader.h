

#pragma once
#ifndef COMPUTE_SHADER
#define COMPUTE_SHADER


#include "stdio.h"
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>

class ComputeShader {

public:
    unsigned int ID;

    ComputeShader(const char* computePath);

    void Use();


    void SetFloat(const std::string& name, float value) const;

    void SetInt(const std::string& name, int value) const;
};

#endif // !COMPUTE_SHADER
