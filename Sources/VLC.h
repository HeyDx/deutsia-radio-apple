#include <stdint.h>
#include <stdlib.h>
typedef struct libvlc_instance_t libvlc_instance_t;
typedef struct libvlc_media_t libvlc_media_t;
typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef struct libvlc_equalizer_t libvlc_equalizer_t;
libvlc_instance_t *libvlc_new(int, const char *const *);
void libvlc_release(libvlc_instance_t *);
libvlc_media_t *libvlc_media_new_location(libvlc_instance_t *, const char *);
void libvlc_media_add_option(libvlc_media_t *, const char *);
void libvlc_media_release(libvlc_media_t *);
char *libvlc_media_get_meta(libvlc_media_t *, int);
void libvlc_free(void *);
libvlc_media_player_t *libvlc_media_player_new_from_media(libvlc_media_t *);
int libvlc_media_player_play(libvlc_media_player_t *);
void libvlc_media_player_set_pause(libvlc_media_player_t *, int);
void libvlc_media_player_stop(libvlc_media_player_t *);
void libvlc_media_player_release(libvlc_media_player_t *);
int libvlc_media_player_get_state(libvlc_media_player_t *);
int libvlc_audio_set_volume(libvlc_media_player_t *, int);
libvlc_equalizer_t *libvlc_audio_equalizer_new(void);
void libvlc_audio_equalizer_release(libvlc_equalizer_t *);
int libvlc_audio_equalizer_set_amp_at_index(libvlc_equalizer_t *, float, unsigned);
int libvlc_media_player_set_equalizer(libvlc_media_player_t *, libvlc_equalizer_t *);
