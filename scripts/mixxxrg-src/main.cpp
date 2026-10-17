// mixxxrg: compute the ReplayGain track gain for a FLAC file exactly the
// way Mixxx 2.5 does, so tags are interchangeable with Mixxx's own
// analysis results.
//
// Mixxx's [ReplayGain] ReplayGainAnalyserVersion defaults to 2 (EBU R128),
// which is what this implements:
//  - sources/soundsourceflac.cpp: libFLAC decode, convertDecodedSample()
//  - sources/audiosourcestereoproxy.cpp: mono -> dual mono, >2ch -> ch 0/1
//  - analyzer/analyzerebur128.cpp: ebur128_init(2, nativeRate, MODE_I),
//    ebur128_add_frames_float() on unscaled -1..1 samples,
//    gain = -18 LUFS - ebur128_loudness_global()
//  - track/replaygain.cpp + util/math.h: db2ratio/ratio2db round trip
//  - track/taglib/trackmetadata_xiph.cpp: REPLAYGAIN_TRACK_GAIN tag
//
// usage: mixxxrg <file.flac>
// prints the tag value (e.g. "-11.0764 dB") on stdout.
// exit codes: 0 ok, 2 usage, 3 unsupported sample rate (Mixxx skips RG
// for these too), 4 decode/analysis error.

#include <ebur128.h>

#include <FLAC/stream_decoder.h>
#include <FLAC/ordinals.h>

#include <cfloat>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

constexpr double kReplayGain2ReferenceLUFS = -18; // like Mixxx

struct Analyzer {
    ebur128_state* state = nullptr;
    bool ok = true; // flipped to false on the first fatal error
    bool initialised = false;
    bool hasStreamInfo = false;
    long sampleRate = 0;
    int bitsPerSample = 0; // from STREAMINFO, like Mixxx's m_bitsPerSample

    // Exact replica of SoundSourceFLAC::convertDecodedSample.
    // kSampleScaleFactor = -CSAMPLE_PEAK / ((FLAC__int32)1 << 31) with
    // CSAMPLE_PEAK = 1.0f; the shift makes the denominator INT32_MIN so
    // the factor is positive (phase preserved).
    float convertDecodedSample(FLAC__int32 decodedSample, int bps) const {
        constexpr float kSampleScaleFactor =
                -1.0f / (static_cast<FLAC__int32>(1) << 31);
        // Mixxx: digits (31) + 1 - bps == 2^(32 - bps), per its source comment
        const auto upscaleShift = 32u - static_cast<unsigned>(bps);
        const auto upscaledSample =
                static_cast<FLAC__int32>(decodedSample << upscaleShift);
        return static_cast<float>(upscaledSample) * kSampleScaleFactor;
    }

    bool processFrame(const FLAC__Frame* frame,
            const FLAC__int32* const buffer[]) {
    if (!ok) {
        return false;
    }
    if (!initialised) {
            if (sampleRate == 0) {
                ok = false;
                return false;
            }
            initialised = true;
            // like AnalyzerEbur128::initialize (kAnalysisChannels = 2)
            state = ebur128_init(2, static_cast<unsigned long>(sampleRate),
                    EBUR128_MODE_I);
            ok = (state != nullptr);
            if (!ok) {
                return false;
            }
        }

        const unsigned int channels = frame->header.channels;
        const size_t frames = frame->header.blocksize;
        // ebur128_add_frames_float expects interleaved -1..1 samples,
        // no extra gain applied (unlike Mixxx's RG 1.0 analyzer).
        std::vector<float> interleaved(frames * 2);
        for (size_t i = 0; i < frames; ++i) {
            float l = 0.f;
            float r = 0.f;
            if (channels == 1) {
                // copyMonoToDualMono: duplicate the channel
                l = r = convertDecodedSample(buffer[0][i], bitsPerSample);
            } else if (channels >= 2) {
                // stereo passthrough / copyMultiToStereo: first two channels
                l = convertDecodedSample(buffer[0][i], bitsPerSample);
                r = convertDecodedSample(buffer[1][i], bitsPerSample);
            }
            interleaved[i * 2] = l;
            interleaved[i * 2 + 1] = r;
        }
        return ebur128_add_frames_float(state, interleaved.data(), frames)
                == EBUR128_SUCCESS;
    }

    // like AnalyzerEbur128::storeResults
    bool finish(double* outGainDb) {
        if (!initialised || !ok || !state) {
            return false;
        }
        double averageLufs = 0.0;
        const int e = ebur128_loudness_global(state, &averageLufs);
        if (e != EBUR128_SUCCESS) {
            return false;
        }
        if (averageLufs == -HUGE_VAL || averageLufs == HUGE_VAL ||
                !std::isnormal(averageLufs)) {
            return false;
        }
        *outGainDb = kReplayGain2ReferenceLUFS - averageLufs;
        return true;
    }
};

FLAC__StreamDecoderWriteStatus write_cb(const FLAC__StreamDecoder*,
        const FLAC__Frame* frame, const FLAC__int32* const buffer[],
        void* client_data) {
    if (!static_cast<Analyzer*>(client_data)->processFrame(frame, buffer)) {
        return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
    }
    return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

void metadata_cb(const FLAC__StreamDecoder*, const FLAC__StreamMetadata* meta,
        void* client_data) {
    Analyzer* analyzer = static_cast<Analyzer*>(client_data);
    if (meta->type == FLAC__METADATA_TYPE_STREAMINFO) {
        if (!analyzer->hasStreamInfo) {
            analyzer->sampleRate = meta->data.stream_info.sample_rate;
            // like Mixxx: first seen bitsPerSample wins (4..32)
            const unsigned bps = meta->data.stream_info.bits_per_sample;
            if (bps >= 4 && bps <= 32) {
                analyzer->bitsPerSample = bps;
            } else {
                analyzer->ok = false;
            }
            analyzer->hasStreamInfo = true;
        }
    }
}

void error_cb(const FLAC__StreamDecoder*,
        FLAC__StreamDecoderErrorStatus status, void*) {
    fprintf(stderr, "mixxxrg: decode error: %s\n",
            FLAC__StreamDecoderErrorStatusString[status]);
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: mixxxrg <file.flac>\n");
        return 2;
    }

    Analyzer analyzer;
    FLAC__StreamDecoder* decoder = FLAC__stream_decoder_new();
    if (decoder == nullptr) {
        fprintf(stderr, "mixxxrg: failed to create decoder\n");
        return 4;
    }
    const FLAC__StreamDecoderInitStatus initStatus =
            FLAC__stream_decoder_init_file(
                    decoder, argv[1],
                    write_cb, metadata_cb, error_cb, &analyzer);
    if (initStatus != FLAC__STREAM_DECODER_INIT_STATUS_OK) {
        fprintf(stderr, "mixxxrg: failed to initialize decoder\n");
        FLAC__stream_decoder_delete(decoder);
        return 4;
    }
    if (!FLAC__stream_decoder_process_until_end_of_stream(decoder)) {
        fprintf(stderr, "mixxxrg: failed to process stream\n");
        FLAC__stream_decoder_finish(decoder);
        FLAC__stream_decoder_delete(decoder);
        return 4;
    }
    FLAC__stream_decoder_finish(decoder);
    FLAC__stream_decoder_delete(decoder);

    if (!analyzer.initialised) {
        fprintf(stderr, "mixxxrg: no audio frames\n");
        return 4;
    }
    if (!analyzer.ok) {
        // Mixxx: ebur128_init() fails for unsupported sample rates and the
        // gain analyzer is skipped entirely.
        fprintf(stderr,
                "mixxxrg: unsupported sample rate %ld (Mixxx skips RG analysis for it)\n",
                analyzer.sampleRate);
        return 3;
    }

    double gainDb = 0.0;
    if (!analyzer.finish(&gainDb)) {
        fprintf(stderr, "mixxxrg: not enough samples for analysis\n");
        return 4;
    }

    // Exact replica of Mixxx's storeResults() + ratioToString():
    //   ratio = db2ratio(gainDb)   (double arithmetic)
    //   db    = ratio2db(ratio)    (double arithmetic)
    //   tag   = QString::number(db, 'g', 6) + " dB"
    const double ratio = std::pow(10.0, gainDb / 20.0);
    const double db = 20.0 * std::log10(ratio);
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%.6g dB", db);
    std::printf("%s\n", buf);
    return 0;
}
