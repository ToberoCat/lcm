#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#ifndef _MSC_VER
#include <unistd.h>
#endif

#include "lcmgen.h"

#define INDENT(n) (2 * (n))

#define emit_start(n, ...)                \
    do {                                  \
        fprintf(f, "%*s", INDENT(n), ""); \
        fprintf(f, __VA_ARGS__);          \
    } while (0)
#define emit_continue(...)       \
    do {                         \
        fprintf(f, __VA_ARGS__); \
    } while (0)
#define emit_end(...)            \
    do {                         \
        fprintf(f, __VA_ARGS__); \
        fprintf(f, "\n");        \
    } while (0)
#define emit(n, ...)                      \
    do {                                  \
        fprintf(f, "%*s", INDENT(n), ""); \
        fprintf(f, __VA_ARGS__);          \
        fprintf(f, "\n");                 \
    } while (0)

static char *dots_to_slashes(const char *s)
{
    char *p = strdup(s);

    for (char *t = p; *t != 0; t++)
        if (*t == '.')
            *t = G_DIR_SEPARATOR;

    return p;
}

// Convert snake_case to PascalCase (e.g., "vector3f_t" -> "Vector3fT")
static char *to_pascal_case(const char *s)
{
    char *result = (char *) malloc(strlen(s) + 1);
    int pos = 0;
    int capitalize_next = 1;  // Capitalize first character

    for (const char *p = s; *p != 0; p++) {
        if (*p == '_') {
            capitalize_next = 1;
        } else {
            if (capitalize_next) {
                result[pos++] = toupper(*p);
                capitalize_next = 0;
            } else {
                result[pos++] = *p;
            }
        }
    }
    result[pos] = '\0';
    return result;
}

static void make_dirs_for_file(const char *path)
{
#ifdef WIN32
    char *dirname = g_path_get_dirname(path);
    g_mkdir_with_parents(dirname, 0755);
    g_free(dirname);
#else
    int len = strlen(path);
    for (int i = 0; i < len; i++) {
        if (path[i] == '/') {
            char *dirpath = (char *) malloc(i + 1);
            strncpy(dirpath, path, i);
            dirpath[i] = 0;

            mkdir(dirpath, 0755);
            free(dirpath);

            i++;  // skip the '/'
        }
    }
#endif
}

void setup_dart_options(getopt_t *gopt)
{
    getopt_add_string(gopt, 0, "dart-path", "", "Dart file destination directory");
    getopt_add_bool(gopt, 0, "dart-mkdir", 1, "Make dart source directories automatically");
}

static const char *map_type_dart(const char *type_name)
{
    if (!strcmp("int8_t", type_name))
        return "int";
    if (!strcmp("int16_t", type_name))
        return "int";
    if (!strcmp("int32_t", type_name))
        return "int";
    if (!strcmp("int64_t", type_name))
        return "int";
    if (!strcmp("byte", type_name))
        return "int";
    if (!strcmp("float", type_name))
        return "double";
    if (!strcmp("double", type_name))
        return "double";
    if (!strcmp("string", type_name))
        return "String";
    if (!strcmp("boolean", type_name))
        return "bool";

    return type_name;
}

static void emit_comment(FILE *f, int indent, const char *comment)
{
    if (!comment)
        return;

    gchar **lines = g_strsplit(comment, "\n", 0);

    for (int line_ind = 0; lines[line_ind]; line_ind++) {
        if (strlen(lines[line_ind])) {
            emit(indent, "/// %s", lines[line_ind]);
        } else {
            emit(indent, "///");
        }
    }
    g_strfreev(lines);
}

static void emit_encode_one(FILE *f, const char *type_name, const char *accessor, int indent)
{
    if (!strcmp(type_name, "byte")) {
        emit(indent, "buf.putUint8(%s);", accessor);
    } else if (!strcmp(type_name, "int8_t")) {
        emit(indent, "buf.putInt8(%s);", accessor);
    } else if (!strcmp(type_name, "int16_t")) {
        emit(indent, "buf.putInt16(%s);", accessor);
    } else if (!strcmp(type_name, "int32_t")) {
        emit(indent, "buf.putInt32(%s);", accessor);
    } else if (!strcmp(type_name, "int64_t")) {
        emit(indent, "buf.putInt64(%s);", accessor);
    } else if (!strcmp(type_name, "float")) {
        emit(indent, "buf.putFloat32(%s);", accessor);
    } else if (!strcmp(type_name, "double")) {
        emit(indent, "buf.putFloat64(%s);", accessor);
    } else if (!strcmp(type_name, "string")) {
        emit(indent, "{");
        emit(indent + 1, "final bytes = utf8.encode(%s);", accessor);
        emit(indent + 1, "buf.putUint32(bytes.length + 1);");
        emit(indent + 1, "buf.putUint8List(bytes);");
        emit(indent + 1, "buf.putUint8(0);");
        emit(indent, "}");
    } else if (!strcmp(type_name, "boolean")) {
        emit(indent, "buf.putUint8(%s ? 1 : 0);", accessor);
    } else {
        emit(indent, "%s.encode(buf);", accessor);
    }
}

static void emit_decode_one(FILE *f, const char *type_name, const char *accessor, int indent)
{
    if (!strcmp(type_name, "byte")) {
        emit(indent, "%sbuf.getUint8();", accessor);
    } else if (!strcmp(type_name, "int8_t")) {
        emit(indent, "%sbuf.getInt8();", accessor);
    } else if (!strcmp(type_name, "int16_t")) {
        emit(indent, "%sbuf.getInt16();", accessor);
    } else if (!strcmp(type_name, "int32_t")) {
        emit(indent, "%sbuf.getInt32();", accessor);
    } else if (!strcmp(type_name, "int64_t")) {
        emit(indent, "%sbuf.getInt64();", accessor);
    } else if (!strcmp(type_name, "float")) {
        emit(indent, "%sbuf.getFloat32();", accessor);
    } else if (!strcmp(type_name, "double")) {
        emit(indent, "%sbuf.getFloat64();", accessor);
    } else if (!strcmp(type_name, "string")) {
        emit(indent, "{");
        emit(indent + 1, "final len = buf.getUint32();");
        emit(indent + 1, "final bytes = buf.getUint8List(len - 1);");
        emit(indent + 1, "buf.getUint8(); // null terminator");
        emit(indent + 1, "%sutf8.decode(bytes);", accessor);
        emit(indent, "}");
    } else if (!strcmp(type_name, "boolean")) {
        emit(indent, "%sbuf.getUint8() != 0;", accessor);
    } else {
        emit(indent, "%s%s.decode(buf);", accessor, map_type_dart(type_name));
    }
}

static int emit_struct(lcmgen_t *lcm, lcm_struct_t *ls, const char *path)
{
    FILE *f = fopen(path, "w");
    if (f == NULL) {
        perror(path);
        return -1;
    }

    fprintf(f,
            "// LCM type definitions\n"
            "// This file automatically generated by lcm-gen.\n"
            "// DO NOT MODIFY BY HAND!!!!\n"
            "\n");

    emit(0, "import 'dart:convert';");
    emit(0, "import 'dart:typed_data';");
    emit(0, "import 'package:lcm_dart/lcm_dart.dart';");
    fprintf(f, "\n");

    char *class_name = to_pascal_case(ls->structname->shortname);
    emit_comment(f, 0, ls->comment);
    emit(0, "class %s implements LcmMessage {", class_name);

    // Emit hash constant
    // Apply the LCM fingerprint transformation: (hash<<1) + ((hash>>63)&1)
    int64_t fingerprint = (ls->hash << 1) + ((ls->hash >> 63) & 1);
    emit(1, "static const int LCM_FINGERPRINT = 0x%016" PRIx64 ";", fingerprint);
    fprintf(f, "\n");

    // Emit constants
    for (unsigned int i = 0; i < ls->constants->len; i++) {
        lcm_constant_t *lc = (lcm_constant_t *) g_ptr_array_index(ls->constants, i);
        emit_comment(f, 1, lc->comment);
        emit(1, "static const %s %s = %s;", map_type_dart(lc->lctypename), lc->membername,
             lc->val_str);
    }
    if (ls->constants->len > 0)
        fprintf(f, "\n");

    // Emit fields
    for (unsigned int i = 0; i < ls->members->len; i++) {
        lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(ls->members, i);
        emit_comment(f, 1, lm->comment);

        if (lm->dimensions->len == 0) {
            emit(1, "%s %s;", map_type_dart(lm->type->lctypename), lm->membername);
        } else {
            emit_start(1, "List");
            for (unsigned int j = 0; j < lm->dimensions->len; j++) {
                emit_continue("<");
            }
            emit_continue("%s", map_type_dart(lm->type->lctypename));
            for (unsigned int j = 0; j < lm->dimensions->len; j++) {
                emit_continue(">");
            }
            emit_end(" %s;", lm->membername);
        }
    }
    fprintf(f, "\n");

    // Constructor
    emit(1, "%s({", class_name);
    for (unsigned int i = 0; i < ls->members->len; i++) {
        lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(ls->members, i);
        if (lm->dimensions->len == 0) {
            emit(2, "required this.%s,", lm->membername);
        } else {
            emit(2, "required this.%s,", lm->membername);
        }
    }
    emit(1, "});");
    fprintf(f, "\n");

    // Fingerprint getter
    emit(1, "@override");
    emit(1, "int get lcmFingerprint => LCM_FINGERPRINT;");
    fprintf(f, "\n");

    // Encode method
    emit(1, "@override");
    emit(1, "void encode(LcmBuffer buf) {");
    emit(2, "buf.putInt64(LCM_FINGERPRINT);");

    for (unsigned int i = 0; i < ls->members->len; i++) {
        lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(ls->members, i);

        if (lm->dimensions->len == 0) {
            // Scalar
            emit_encode_one(f, lm->type->lctypename, lm->membername, 2);
        } else {
            // Array
            for (unsigned int dim = 0; dim < lm->dimensions->len; dim++) {
                lcm_dimension_t *ld =
                    (lcm_dimension_t *) g_ptr_array_index(lm->dimensions, dim);

                // Don't encode dimension size - it's already encoded as part of the variable field
                emit(2 + dim, "for (var i%d = 0; i%d < %s; i%d++) {", dim, dim, ld->size, dim);
            }

            // Generate accessor
            GString *accessor = g_string_new(lm->membername);
            for (unsigned int dim = 0; dim < lm->dimensions->len; dim++) {
                g_string_append_printf(accessor, "[i%d]", dim);
            }

            emit_encode_one(f, lm->type->lctypename, accessor->str, 2 + lm->dimensions->len);
            g_string_free(accessor, TRUE);

            for (unsigned int dim = 0; dim < lm->dimensions->len; dim++) {
                emit(2 + lm->dimensions->len - 1 - dim, "}");
            }
        }
    }

    emit(1, "}");
    fprintf(f, "\n");

    // Decode static method
    emit(1, "static %s decode(LcmBuffer buf) {", class_name);
    emit(2, "final fingerprint = buf.getInt64();");
    emit(2, "if (fingerprint != LCM_FINGERPRINT) {");
    emit(3, "throw Exception('Invalid fingerprint');");
    emit(2, "}");
    fprintf(f, "\n");

    // Decode fields
    for (unsigned int i = 0; i < ls->members->len; i++) {
        lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(ls->members, i);

        if (lm->dimensions->len == 0) {
            // Scalar
            emit_start(2, "final %s = ", lm->membername);
            if (!strcmp(lm->type->lctypename, "byte")) {
                emit_end("buf.getUint8();");
            } else if (!strcmp(lm->type->lctypename, "int8_t")) {
                emit_end("buf.getInt8();");
            } else if (!strcmp(lm->type->lctypename, "int16_t")) {
                emit_end("buf.getInt16();");
            } else if (!strcmp(lm->type->lctypename, "int32_t")) {
                emit_end("buf.getInt32();");
            } else if (!strcmp(lm->type->lctypename, "int64_t")) {
                emit_end("buf.getInt64();");
            } else if (!strcmp(lm->type->lctypename, "float")) {
                emit_end("buf.getFloat32();");
            } else if (!strcmp(lm->type->lctypename, "double")) {
                emit_end("buf.getFloat64();");
            } else if (!strcmp(lm->type->lctypename, "string")) {
                emit_end("() {");
                emit(3, "final len = buf.getUint32();");
                emit(3, "final bytes = buf.getUint8List(len - 1);");
                emit(3, "buf.getUint8(); // null terminator");
                emit(3, "return utf8.decode(bytes);");
                emit(2, "}();");
            } else if (!strcmp(lm->type->lctypename, "boolean")) {
                emit_end("buf.getUint8() != 0;");
            } else {
                emit_end("%s.decode(buf);", map_type_dart(lm->type->lctypename));
            }
        } else {
            // Array
            // Create nested list structure
            emit_start(2, "final %s = ", lm->membername);
            emit_continue("List.generate(");

            lcm_dimension_t *first_dim =
                (lcm_dimension_t *) g_ptr_array_index(lm->dimensions, 0);
            emit_continue("%s, (_) => ", first_dim->size);

            for (unsigned int dim = 1; dim < lm->dimensions->len; dim++) {
                lcm_dimension_t *ld =
                    (lcm_dimension_t *) g_ptr_array_index(lm->dimensions, dim);
                emit_continue("List.generate(%s, (_) => ", ld->size);
            }

            // Now emit the decode call for the innermost element
            if (!strcmp(lm->type->lctypename, "byte")) {
                emit_continue("buf.getUint8()");
            } else if (!strcmp(lm->type->lctypename, "int8_t")) {
                emit_continue("buf.getInt8()");
            } else if (!strcmp(lm->type->lctypename, "int16_t")) {
                emit_continue("buf.getInt16()");
            } else if (!strcmp(lm->type->lctypename, "int32_t")) {
                emit_continue("buf.getInt32()");
            } else if (!strcmp(lm->type->lctypename, "int64_t")) {
                emit_continue("buf.getInt64()");
            } else if (!strcmp(lm->type->lctypename, "float")) {
                emit_continue("buf.getFloat32()");
            } else if (!strcmp(lm->type->lctypename, "double")) {
                emit_continue("buf.getFloat64()");
            } else if (!strcmp(lm->type->lctypename, "string")) {
                emit_continue("() {");
                emit(3, "final len = buf.getUint32();");
                emit(3, "final bytes = buf.getUint8List(len - 1);");
                emit(3, "buf.getUint8();");
                emit(3, "return utf8.decode(bytes);");
                emit_start(2, "}()");
            } else if (!strcmp(lm->type->lctypename, "boolean")) {
                emit_continue("buf.getUint8() != 0");
            } else {
                emit_continue("%s.decode(buf)", map_type_dart(lm->type->lctypename));
            }

            for (unsigned int dim = 0; dim < lm->dimensions->len; dim++) {
                emit_continue(")");
            }
            emit_end(";");
        }
    }
    fprintf(f, "\n");

    // Return constructed object
    emit(2, "return %s(", class_name);
    for (unsigned int i = 0; i < ls->members->len; i++) {
        lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(ls->members, i);
        emit(3, "%s: %s,", lm->membername, lm->membername);
    }
    emit(2, ");");
    emit(1, "}");

    emit(0, "}");

    free(class_name);
    fclose(f);
    return 0;
}

int emit_dart(lcmgen_t *lcm)
{
    const char *dart_path = getopt_get_string(lcm->gopt, "dart-path");
    if (strlen(dart_path) == 0)
        dart_path = ".";

    int make_dirs = getopt_get_bool(lcm->gopt, "dart-mkdir");

    for (unsigned int i = 0; i < lcm->structs->len; i++) {
        lcm_struct_t *ls = (lcm_struct_t *) g_ptr_array_index(lcm->structs, i);

        char *package_dir = dots_to_slashes(ls->structname->package);
        char path[1024];
        snprintf(path, sizeof(path), "%s%s%s%s%s.g.dart", dart_path, strlen(dart_path) > 0 ? "/" : "",
                 package_dir, strlen(package_dir) > 0 ? "/" : "", ls->structname->shortname);

        if (make_dirs)
            make_dirs_for_file(path);

        if (!lcm_needs_generation(lcm, ls->lcmfile, path))
            continue;

        int status = emit_struct(lcm, ls, path);
        if (status != 0) {
            free(package_dir);
            return status;
        }

        free(package_dir);
    }

    return 0;
}
