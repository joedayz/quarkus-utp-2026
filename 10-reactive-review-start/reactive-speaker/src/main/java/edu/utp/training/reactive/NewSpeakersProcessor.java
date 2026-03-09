package edu.utp.training.reactive;

import edu.utp.training.model.Affiliation;
import jakarta.enterprise.context.ApplicationScoped;
import org.jboss.logging.Logger;

@ApplicationScoped
public class NewSpeakersProcessor {
    private static final Logger LOGGER = Logger.getLogger(NewSpeakersProcessor.class);

    private void logEmitEvent(String eventName, Affiliation affiliation) {
        LOGGER.infov(
                "Sending event {0} for affiliation {1}",
                eventName,
                affiliation
        );
    }

    private void logProcessEvent(Long eventID) {
        LOGGER.infov(
                "Processing SpeakerWasCreated event: ID {0}",
                eventID
        );
    }
}

