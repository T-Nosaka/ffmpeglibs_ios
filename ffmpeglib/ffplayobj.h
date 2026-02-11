//
// Created by dangerouswoo on 2025/04/26.
//

#ifndef VIDEO_TRANS_BATCH_FFPLAYOBJ_H
#define VIDEO_TRANS_BATCH_FFPLAYOBJ_H

#ifdef __cplusplus
extern "C" {
#endif

#include "config.h"
#include "config_components.h"
#include <math.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>

#include "libavutil/avstring.h"
#include "libavutil/channel_layout.h"
#include "libavutil/mathematics.h"
#include "libavutil/mem.h"
#include "libavutil/pixdesc.h"
#include "libavutil/dict.h"
#include "libavutil/fifo.h"
#include "libavutil/samplefmt.h"
#include "libavutil/time.h"
#include "libavutil/bprint.h"
#include "libavformat/avformat.h"
#include "libavdevice/avdevice.h"
#include "libswscale/swscale.h"
#include "libavutil/opt.h"
#include "libavutil/tx.h"
#include "libswresample/swresample.h"

#include "libavfilter/avfilter.h"
#include "libavfilter/buffersink.h"
#include "libavfilter/buffersrc.h"

#include <SDL.h>
#include <SDL_thread.h>

#define class aclass
#include "cmdutils.h"
#undef class
#include "ffplay_renderer.h"
#include "opt_common.h"

#ifdef __cplusplus
}
#endif

#include <functional>
#include <string>

/* NOTE: the size must be big enough to compensate the hardware audio buffersize size */
/* TODO: We assume that a decoded and resampled frame fits into this buffer */
#define SAMPLE_ARRAY_SIZE (8 * 65536)

#define USE_ONEPASS_SUBTITLE_RENDER 1

#define VIDEO_PICTURE_QUEUE_SIZE 3
#define SUBPICTURE_QUEUE_SIZE 16
#define SAMPLE_QUEUE_SIZE 9
#define FRAME_QUEUE_SIZE FFMAX(SAMPLE_QUEUE_SIZE, FFMAX(VIDEO_PICTURE_QUEUE_SIZE, SUBPICTURE_QUEUE_SIZE))

#define FF_QUIT_EVENT    (SDL_USEREVENT + 2)

class ffplayobj {

public:
    ffplayobj();
    virtual ~ffplayobj();

protected:

    const int MAX_QUEUE_SIZE = (15 * 1024 * 1024);
    const int MIN_FRAMES = 25;
    const int EXTERNAL_CLOCK_MIN_FRAMES = 2;
    const int EXTERNAL_CLOCK_MAX_FRAMES = 10;
    /* Minimum SDL audio buffer size, in samples. */
    const int SDL_AUDIO_MIN_BUFFER_SIZE = 512;
    /* Calculate actual buffer size keeping in mind not cause too frequent audio callbacks */
    const int SDL_AUDIO_MAX_CALLBACKS_PER_SEC = 30;

    /* no AV sync correction is done if below the minimum AV sync threshold */
    const double AV_SYNC_THRESHOLD_MIN = 0.04;
    /* AV sync correction is done if above the maximum AV sync threshold */
    const double AV_SYNC_THRESHOLD_MAX = 0.1;
    /* If a frame duration is longer than this, it will not be duplicated to compensate AV sync */
    const double AV_SYNC_FRAMEDUP_THRESHOLD = 0.1;
    /* no AV correction is done if too big error */
    const double AV_NOSYNC_THRESHOLD = 10.0;

    /* maximum audio speed change to get correct sync */
    const int SAMPLE_CORRECTION_PERCENT_MAX = 10;

    /* external clock speed adjustment constants for realtime sources based on buffer fullness */
    const double EXTERNAL_CLOCK_SPEED_MIN = 0.900;
    const double EXTERNAL_CLOCK_SPEED_MAX = 1.010;
    const double EXTERNAL_CLOCK_SPEED_STEP = 0.001;

    /* we use about AUDIO_DIFF_AVG_NB A-V differences to make the average */
    const int AUDIO_DIFF_AVG_NB = 20;

    /* polls for possible required screen refresh at least this often, should be less than 1/fps */
    const double REFRESH_RATE = 0.01;

    typedef struct MyAVPacketList {
        AVPacket *pkt;
        int serial;
    } MyAVPacketList;

    typedef struct PacketQueue {
        AVFifo *pkt_list;
        int nb_packets;
        int size;
        int64_t duration;
        int abort_request;
        int serial;
        SDL_mutex *mutex;
        SDL_cond *cond;
    } PacketQueue;

    typedef struct AudioParams {
        int freq;
        AVChannelLayout ch_layout;
        enum AVSampleFormat fmt;
        int frame_size;
        int bytes_per_sec;
    } AudioParams;

    typedef struct Clock {
        double pts;           /* clock base */
        double pts_drift;     /* clock base minus time at which we updated the clock */
        double last_updated;
        double speed;
        int serial;           /* clock is based on a packet with this serial */
        int paused;
        int *queue_serial;    /* pointer to the current packet queue serial, used for obsolete clock detection */
    } Clock;

    typedef struct FrameData {
        int64_t pkt_pos;
    } FrameData;

    /* Common struct for handling all types of decoded data and allocated render buffers. */
    typedef struct Frame {
        AVFrame *frame;
        AVSubtitle sub;
        int serial;
        double pts;           /* presentation timestamp for the frame */
        double duration;      /* estimated duration of the frame */
        int64_t pos;          /* byte position of the frame in the input file */
        int width;
        int height;
        int format;
        AVRational sar;
        int uploaded;
        int flip_v;
    } Frame;

    typedef struct FrameQueue {
        Frame queue[FRAME_QUEUE_SIZE];
        int rindex;
        int windex;
        int size;
        int max_size;
        int keep_last;
        int rindex_shown;
        SDL_mutex *mutex;
        SDL_cond *cond;
        PacketQueue *pktq;
    } FrameQueue;

    enum {
        AV_SYNC_AUDIO_MASTER, /* default choice */
        AV_SYNC_VIDEO_MASTER,
        AV_SYNC_EXTERNAL_CLOCK, /* synchronize to an external clock */
    };

    typedef struct Decoder {
        AVPacket *pkt;
        PacketQueue *queue;
        AVCodecContext *avctx;
        int pkt_serial;
        int finished;
        int packet_pending;
        SDL_cond *empty_queue_cond;
        int64_t start_pts;
        AVRational start_pts_tb;
        int64_t next_pts;
        AVRational next_pts_tb;
        SDL_Thread *decoder_tid;
    } Decoder;

    typedef struct VideoState {
        SDL_Thread *read_tid;
        const AVInputFormat *iformat;
        int abort_request;
        int force_refresh;
        int paused;
        int last_paused;
        int queue_attachments_req;
        int seek_req;
        int seek_flags;
        int64_t seek_pos;
        int64_t seek_rel;
        int read_pause_return;
        AVFormatContext *ic;
        int realtime;

        Clock audclk;
        Clock vidclk;
        Clock extclk;

        FrameQueue pictq;
        FrameQueue subpq;
        FrameQueue sampq;

        Decoder auddec;
        Decoder viddec;
        Decoder subdec;

        int audio_stream;

        int av_sync_type;

        double audio_clock;
        int audio_clock_serial;
        double audio_diff_cum; /* used for AV difference average computation */
        double audio_diff_avg_coef;
        double audio_diff_threshold;
        int audio_diff_avg_count;
        AVStream *audio_st;
        PacketQueue audioq;
        int audio_hw_buf_size;
        uint8_t *audio_buf;
        uint8_t *audio_buf1;
        unsigned int audio_buf_size; /* in bytes */
        unsigned int audio_buf1_size;
        int audio_buf_index; /* in bytes */
        int audio_write_buf_size;
        int audio_volume;
        int muted;
        struct AudioParams audio_src;
        struct AudioParams audio_filter_src;
        struct AudioParams audio_tgt;
        struct SwrContext *swr_ctx;
        int frame_drops_early;
        int frame_drops_late;

        enum ShowMode {
            SHOW_MODE_NONE = -1, SHOW_MODE_VIDEO = 0, SHOW_MODE_WAVES, SHOW_MODE_RDFT, SHOW_MODE_NB
        } show_mode;
        int16_t sample_array[SAMPLE_ARRAY_SIZE];
        int sample_array_index;
        int last_i_start;
        AVTXContext *rdft;
        av_tx_fn rdft_fn;
        int rdft_bits;
        float *real_data;
        AVComplexFloat *rdft_data;
        int xpos;
        double last_vis_time;

        int subtitle_stream;
        AVStream *subtitle_st;
        PacketQueue subtitleq;

        double frame_timer;
        double frame_last_returned_time;
        double frame_last_filter_delay;
        int video_stream;
        AVStream *video_st;
        PacketQueue videoq;
        double max_frame_duration;      // maximum duration of a frame - above this, we consider the jump a timestamp discontinuity
        struct SwsContext *sub_convert_ctx;
        int eof;

        char *filename;
        int width, height, xleft, ytop;
        int step;

        int vfilter_idx;
        AVFilterContext *in_video_filter;   // the first filter in the video chain
        AVFilterContext *out_video_filter;  // the last filter in the video chain
        AVFilterContext *in_audio_filter;   // the first filter in the audio chain
        AVFilterContext *out_audio_filter;  // the last filter in the audio chain
        AVFilterGraph *agraph;              // audio filter graph

        int last_video_stream, last_audio_stream, last_subtitle_stream;

        SDL_cond *continue_read_thread;
    } VideoState;

public:
    
    int default_width ;
    int default_height ;
    int screen_width ;
    int screen_height;
    int screen_left ;
    int screen_top ;
    int audio_disable;
    int video_disable;
    int subtitle_disable;
    const char* wanted_stream_spec[AVMEDIA_TYPE_NB];
    int seek_by_bytes ;
    float seek_interval;
    int display_disable;
    int borderless;
    int alwaysontop;
    int startup_volume;
    int show_status ;
    int av_sync_type ;
    int64_t start_time;
    int64_t duration;
    int fast ;
    int genpts ;
    int lowres ;
    int decoder_reorder_pts ;
    int autoexit;
    int exit_on_keydown;
    int exit_on_mousedown;
    int loop ;
    int framedrop ;
    int infinite_buffer ;
    enum VideoState::ShowMode show_mode;
    double rdftspeed ;
    int64_t cursor_last_shown;
    int cursor_hidden;
    const char **vfilters_list ;
    int nb_vfilters ;
    char *afilters ;
    int autorotate ;
    int find_stream_info ;
    int filter_nbthreads ;

    struct TextureFormatEntry {
        enum AVPixelFormat format;
        int texture_fmt;
    };
    static struct TextureFormatEntry sdl_texture_format_map[];

    AVDictionary *sws_dict;
    AVDictionary *swr_opts;
    AVDictionary *format_opts, *codec_opts;

private:

    VideoState *m_is;

    int opt_add_vfilter(void *optctx, const char *opt, const char *arg);
    int cmp_audio_fmts(enum AVSampleFormat fmt1, int64_t channel_count1, enum AVSampleFormat fmt2, int64_t channel_count2);

    static int packet_queue_put_private(PacketQueue *q, AVPacket *pkt);
    static int packet_queue_put(PacketQueue *q, AVPacket *pkt) {
        AVPacket *pkt1;
        int ret;

        pkt1 = av_packet_alloc();
        if (!pkt1) {
            av_packet_unref(pkt);
            return -1;
        }
        av_packet_move_ref(pkt1, pkt);

        SDL_LockMutex(q->mutex);
        ret = packet_queue_put_private(q, pkt1);
        SDL_UnlockMutex(q->mutex);

        if (ret < 0)
            av_packet_free(&pkt1);

        return ret;
    }
    static int packet_queue_put_nullpacket(PacketQueue *q, AVPacket *pkt, int stream_index) {
        pkt->stream_index = stream_index;
        return packet_queue_put(q, pkt);
    }
    static int packet_queue_init(PacketQueue *q);
    static void packet_queue_flush(PacketQueue *q);
    static void packet_queue_destroy(PacketQueue *q);
    static void packet_queue_abort(PacketQueue *q);
    static void packet_queue_start(PacketQueue *q);
    static int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block, int *serial);

    int decoder_init(Decoder *d, AVCodecContext *avctx, PacketQueue *queue, SDL_cond *empty_queue_cond);
    int decoder_decode_frame(Decoder *d, AVFrame *frame, AVSubtitle *sub);
    void decoder_destroy(Decoder *d);

    static void frame_queue_unref_item(Frame *vp) {
        av_frame_unref(vp->frame);
        avsubtitle_free(&vp->sub);
    }
    static int frame_queue_init(FrameQueue *f, PacketQueue *pktq, int max_size, int keep_last);
    static void frame_queue_destroy(FrameQueue *f);
    static void frame_queue_signal(FrameQueue *f) {
        SDL_LockMutex(f->mutex);
        SDL_CondSignal(f->cond);
        SDL_UnlockMutex(f->mutex);
    }
    static Frame* frame_queue_peek(FrameQueue *f) {
        return &f->queue[(f->rindex + f->rindex_shown) % f->max_size];
    }
    static Frame* frame_queue_peek_next(FrameQueue *f) {
        return &f->queue[(f->rindex + f->rindex_shown + 1) % f->max_size];
    }
    static Frame* frame_queue_peek_last(FrameQueue *f) {
        return &f->queue[f->rindex];
    }
    static Frame* frame_queue_peek_writable(FrameQueue *f);
    static Frame* frame_queue_peek_readable(FrameQueue *f);
    static void frame_queue_push(FrameQueue *f);
    static void frame_queue_next(FrameQueue *f);
    /* return the number of undisplayed frames in the queue */
    static int frame_queue_nb_remaining(FrameQueue *f) {
        return f->size - f->rindex_shown;
    }
    /* return last shown position */
    static int64_t frame_queue_last_pos(FrameQueue *f) {
        Frame *fp = &f->queue[f->rindex];
        if (f->rindex_shown && fp->serial == f->pktq->serial)
            return fp->pos;
        else
            return -1;
    }

    void decoder_abort(Decoder *d, FrameQueue *fq);
    void fill_rectangle(int x, int y, int w, int h) {}
    int upload_texture(VideoState *is, AVFrame *frame) {
        //VIDEOTRANSBATCH  描画コールバック
        if (frame->linesize[0] < 0) {
            if(m_upload_texture_cb)
                m_upload_texture_cb( *this, frame->width, frame->height, frame->format, frame->data[0] + frame->linesize[0] * (frame->height - 1), -frame->linesize[0] );
        } else {
            if(m_upload_texture_cb)
                m_upload_texture_cb( *this, frame->width, frame->height, frame->format, frame->data[0], frame->linesize[0] );
        }
        return 0;
    }
    void set_sdl_yuv_conversion_mode(AVFrame *frame) {};
    void video_image_display(VideoState *is);
    static int compute_mod(int a, int b) {return a < 0 ? a%b + b : a%b;}
    void stream_component_close(VideoState *is, int stream_index);
    void stream_close(VideoState *is);
    void set_default_window_size(int width, int height, AVRational sar) {}

    int video_open(VideoState *is);
    void video_display(VideoState *is);
    double get_clock(Clock *c);
    void set_clock_at(Clock *c, double pts, int serial, double time);
    void set_clock(Clock *c, double pts, int serial);
    void set_clock_speed(Clock *c, double speed);
    void init_clock(Clock *c, int *queue_serial);
    void sync_clock_to_slave(Clock *c, Clock *slave);
    int get_master_sync_type(VideoState *is);
    double get_master_clock(VideoState *is);
    void check_external_clock_speed(VideoState *is);
    void stream_seek(VideoState *is, int64_t pos, int64_t rel, int by_bytes);
    void stream_toggle_pause(VideoState *is);
    void toggle_pause(VideoState *is) {
        stream_toggle_pause(is);
        is->step = 0;
    }
    static void toggle_mute(VideoState *is) {
        is->muted = !is->muted;
    }
    static void update_volume(VideoState *is, int sign, double step) {
        double volume_level = is->audio_volume ? (20 * log(is->audio_volume / (double)SDL_MIX_MAXVOLUME) / log(10)) : -1000.0;
        int new_volume = lrint(SDL_MIX_MAXVOLUME * pow(10.0, (volume_level + sign * step) / 20.0));
        is->audio_volume = av_clip(is->audio_volume == new_volume ? (is->audio_volume + sign) : new_volume, 0, SDL_MIX_MAXVOLUME);
    }
    void step_to_next_frame(VideoState *is) {
        /* if the stream is paused unpause it, then step */
        if (is->paused)
            stream_toggle_pause(is);
        is->step = 1;
    }
    double compute_target_delay(double delay, VideoState *is);
    static double vp_duration(VideoState *is, Frame *vp, Frame *nextvp) {
        if (vp->serial == nextvp->serial) {
            double duration = nextvp->pts - vp->pts;
            if (isnan(duration) || duration <= 0 || duration > is->max_frame_duration)
                return vp->duration;
            else
                return duration;
        } else {
            return 0.0;
        }
    }
    void update_video_pts(VideoState *is, double pts, int serial) {
        /* update current video pts */
        set_clock(&is->vidclk, pts, serial);
        sync_clock_to_slave(&is->extclk, &is->vidclk);
    }
    void video_refresh(void *opaque, double *remaining_time);
    int queue_picture(VideoState *is, AVFrame *src_frame, double pts, double lduration, int64_t pos, int serial);
    int get_video_frame(VideoState *is, AVFrame *frame);
    int configure_filtergraph(AVFilterGraph *graph, const char *filtergraph, AVFilterContext *source_ctx, AVFilterContext *sink_ctx);
    int configure_video_filters(AVFilterGraph *graph, VideoState *is, const char *vfilters, AVFrame *frame);
    int configure_audio_filters(VideoState *is, const char *afilters, int force_output_format);
    int audio_thread(void *arg);
    static int audio_thread_wrap(void *arg) {
        auto thisobj = static_cast<ffplayobj*>(arg);
        return thisobj->audio_thread(thisobj->m_is);
    }
    int decoder_start(Decoder *d, int (*fn)(void *), const char *thread_name, void* arg);
    int video_thread(void *arg);
    static int video_thread_wrap(void *arg) {
        auto thisobj = static_cast<ffplayobj*>(arg);
        return thisobj->video_thread(thisobj->m_is);
    }
    int subtitle_thread(void *arg);
    static int subtitle_thread_wrap(void *arg) {
        auto thisobj = static_cast<ffplayobj*>(arg);
        return thisobj->subtitle_thread(thisobj->m_is);
    }
    void update_sample_display(VideoState *is, short *samples, int samples_size);
    int synchronize_audio(VideoState *is, int nb_samples);
    int audio_decode_frame(VideoState *is);
    void sdl_audio_callback(void *opaque, Uint8 *stream, int len);
    static void sdl_audio_callback_wrap(void *opaque, Uint8 *stream, int len) {
        auto thisobj = static_cast<ffplayobj*>(opaque);
        thisobj->sdl_audio_callback(thisobj->m_is, stream, len);
    }
    int audio_open(VideoState *opaque, AVChannelLayout *wanted_channel_layout, int wanted_sample_rate, struct AudioParams *audio_hw_params);
    int stream_component_open(VideoState *is, int stream_index);
    static int decode_interrupt_cb(void *ctx)
    {
        auto thisobj = static_cast<ffplayobj*>(ctx);
        return thisobj->m_is->abort_request;
    }

    int stream_has_enough_packets(AVStream *st, int stream_id, PacketQueue *queue) const {
        return stream_id < 0 ||
               queue->abort_request ||
               (st->disposition & AV_DISPOSITION_ATTACHED_PIC) ||
               queue->nb_packets > MIN_FRAMES && (!queue->duration || av_q2d(st->time_base) * queue->duration > 1.0);
    }
    static int is_realtime(AVFormatContext *s) {
        if(   !strcmp(s->iformat->name, "rtp")
              || !strcmp(s->iformat->name, "rtsp")
              || !strcmp(s->iformat->name, "sdp")
                )
            return 1;

        if(s->pb && (   !strncmp(s->url, "rtp:", 4)
                        || !strncmp(s->url, "udp:", 4)
        )
                )
            return 1;
        return 0;
    }
    int read_thread(void *arg);
    static int read_thread_wrap(void *arg) {
        auto thisobj = static_cast<ffplayobj*>(arg);
        return thisobj->read_thread(thisobj->m_is);
    }
    VideoState *stream_open(const char *filename, const AVInputFormat *iformat);
    void stepbystep(VideoState *cur_stream, double now, int64_t stepll, int64_t iDuration);
    void event_loop(VideoState *cur_stream);
    void ffplay_release(VideoState *is);

private:
    // definistion callback outside
    std::function<bool(ffplayobj&)> m_onexit;
    std::function<void(ffplayobj&, double pos, double clock, int pause )> m_onclick;
    std::function<void(ffplayobj&, int width, int height, int format, const void *pixels, int pitch )> m_upload_texture_cb;
    std::function<bool(ffplayobj&, int64_t* control, float* fargs)> m_oncontrol;
    std::function<bool(ffplayobj&, int channel, int sample_rate)> m_readyaudiodevice;
    std::function<void(ffplayobj&)> m_onstartaudio;
    std::function<void(ffplayobj&)> m_onstopaudio;
    std::function<void(ffplayobj&,AVSubtitle&)> m_update_subtile_cb;

public:

    void audiocallback(Uint8 *stream, int len) {
        sdl_audio_callback(m_is, stream, len);
    }

    /*
    * set callback outside
    */
    void setExtCallback(
        std::function<bool(ffplayobj&)> onexit = nullptr,
        std::function<void(ffplayobj&,double pos, double clock, int pause )> onclock = nullptr,
        std::function<void(ffplayobj&, int width, int height, int format, const void *pixels, int pitch )> upload_texture_cb = nullptr,
        std::function<bool(ffplayobj&, int64_t* control, float* fargs )> oncontrol = nullptr,
        std::function<bool(ffplayobj&, int channel, int sample_rate)> readyaudiodevice = nullptr,
        std::function<void(ffplayobj&)> onstartaudio = nullptr,
        std::function<void(ffplayobj&)> onstopaudio = nullptr,
        std::function<void(ffplayobj&,AVSubtitle&)> update_subtile_cb = nullptr ) {

        m_onexit = onexit;
        m_onclick = onclock;
        m_upload_texture_cb = upload_texture_cb;
        m_oncontrol = oncontrol;
        m_readyaudiodevice = readyaudiodevice;
        m_onstartaudio = onstartaudio;
        m_onstopaudio = onstopaudio;
        m_update_subtile_cb = update_subtile_cb;
    }

    void setAudio( bool bAudio ) { audio_disable = bAudio ? 0 : 1; }
    void setVideo( bool bVideo ) { video_disable = bVideo ? 0 : 1; }
    void setSubTitle( bool bSubtitle ) { subtitle_disable = bSubtitle ? 0 : 1; }
    void setAutoexit( bool bAutoexit ) { autoexit = bAutoexit ? 1 : 0; }

    int play(const std::string& strfilename, std::string vfilter, std::string afilter );
};


#endif //VIDEO_TRANS_BATCH_FFPLAYOBJ_H
