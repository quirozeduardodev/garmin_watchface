#include <libmtp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
/* uso: mtpput <archivo local> <id carpeta destino> <nombre remoto> */
int main(int argc, char **argv) {
    if (argc != 4) { fprintf(stderr, "uso: mtpput local parent_id nombre\n"); return 2; }
    LIBMTP_Init();
    LIBMTP_mtpdevice_t *d = LIBMTP_Get_First_Device();
    if (!d) { puts("no hay dispositivo"); return 1; }
    LIBMTP_Get_Storage(d, LIBMTP_STORAGE_SORTBY_NOTSORTED);
    if (!d->storage) { puts("sin almacenamiento"); return 1; }
    struct stat st; if (stat(argv[1], &st) != 0) { perror("stat"); return 1; }
    LIBMTP_file_t *f = LIBMTP_new_file_t();
    f->filename = strdup(argv[3]);
    f->filesize = st.st_size;
    f->filetype = LIBMTP_FILETYPE_UNKNOWN;
    f->parent_id = (uint32_t)strtoul(argv[2], NULL, 10);
    f->storage_id = d->storage->id;
    int r = LIBMTP_Send_File_From_File(d, argv[1], f, NULL, NULL);
    if (r) { LIBMTP_Dump_Errorstack(d); LIBMTP_Clear_Errorstack(d); }
    else printf("ok: id=%u, %llu bytes\n", f->item_id, (unsigned long long)f->filesize);
    LIBMTP_Release_Device(d);
    return r;
}
