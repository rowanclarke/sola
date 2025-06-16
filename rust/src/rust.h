#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

void* chars_map(
  const unsigned char* usfm,
  size_t len,
  const unsigned int** out,
  size_t* out_len
);

void insert(
  void* map,
  unsigned int chr,
  float width,
  float height
);

