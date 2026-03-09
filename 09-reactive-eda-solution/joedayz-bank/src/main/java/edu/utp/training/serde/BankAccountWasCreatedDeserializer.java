package edu.utp.training.serde;

import edu.utp.training.event.BankAccountWasCreated;
import io.quarkus.kafka.client.serialization.ObjectMapperDeserializer;

public class BankAccountWasCreatedDeserializer extends
        ObjectMapperDeserializer<BankAccountWasCreated> {
    public BankAccountWasCreatedDeserializer() {
        super(BankAccountWasCreated.class);
    }
}
