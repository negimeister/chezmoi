#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <alsa/asoundlib.h>
#include <time.h>

snd_seq_t *seq_handle;
int port;

/* Utility function for debug messages */
void log_debug(const char *message, ...)
{
    va_list args;
    va_start(args, message);

    char buffer[256];
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);

    strftime(buffer, sizeof(buffer), "[%Y-%m-%d %H:%M:%S] DEBUG: ", tm_info);
    fputs(buffer, stdout);

    vfprintf(stdout, message, args);
    fputc('\n', stdout);

    va_end(args);
}

/* Open ALSA sequencer and create port */
int open_alsa_seq(char *name)
{
    if (snd_seq_open(&seq_handle, "default", SND_SEQ_OPEN_DUPLEX, 0) < 0) {
        fprintf(stderr, "Error: Failed to open ALSA sequencer.\n");
        exit(EXIT_FAILURE);
    }

    log_debug("ALSA sequencer opened.");

    snd_seq_set_client_name(seq_handle, name);
    log_debug("Client name set to '%s'.", name);

    port = snd_seq_create_simple_port(seq_handle, name,
                                      SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_WRITE |
                                      SND_SEQ_PORT_CAP_SUBS_READ | SND_SEQ_PORT_CAP_SUBS_WRITE,
                                      SND_SEQ_PORT_TYPE_APPLICATION);
    if (port < 0) {
        fprintf(stderr, "Error: Failed to create port.\n");
        snd_seq_close(seq_handle);
        exit(EXIT_FAILURE);
    }

    log_debug("Port '%s' created.", name);
    return port;
}

/* Process incoming MIDI events */
void process_midi_events()
{
    snd_seq_event_t *event;

    log_debug("Starting MIDI event processing...");

    while (1) {
        /* Wait for an event */
        int result = snd_seq_event_input(seq_handle, &event);
        if (result < 0) {
            log_debug("Failed to read event: %d", result);
            continue;
        }

        /* Log the received event */
        log_debug("Received event: type=%d, channel=%d", event->type, event->data.note.channel);

        /* Modify the event if necessary (e.g., log or add meta information) */

        /* Forward the event to all subscribers */
        snd_seq_ev_set_source(event, port);   // Set the source to the dummy port
        snd_seq_ev_set_subs(event);           // Forward to all subscribers
        snd_seq_ev_set_direct(event);         // Deliver immediately

        int out_result = snd_seq_event_output(seq_handle, event);
        if (out_result < 0) {
            log_debug("Failed to send event: %d", out_result);
        } else {
            log_debug("Event sent to subscribers.");
        }

        snd_seq_drain_output(seq_handle); // Ensure the event is flushed
    }
}

int main(int argc, char *argv[])
{
    char *name = "Dummy Port";
    if (argc > 1) {
        name = argv[1];
    }

    open_alsa_seq(name);

    log_debug("Dummy port '%s' ready. Press Ctrl+C to terminate.", name);

    process_midi_events();

    /* Clean up (never reached in this implementation) */
    snd_seq_close(seq_handle);
    log_debug("ALSA sequencer closed.");
    return 0;
}
