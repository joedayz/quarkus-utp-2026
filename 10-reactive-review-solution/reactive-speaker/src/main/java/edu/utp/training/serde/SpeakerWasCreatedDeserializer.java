package edu.utp.training.serde;

import edu.utp.training.event.SpeakerWasCreated;
import io.quarkus.kafka.client.serialization.ObjectMapperDeserializer;

public class SpeakerWasCreatedDeserializer
        extends ObjectMapperDeserializer<SpeakerWasCreated> {
    public  SpeakerWasCreatedDeserializer() {
        super(SpeakerWasCreated.class);
    }
}
