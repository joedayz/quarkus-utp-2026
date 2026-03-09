package edu.utp.training.speaker.idgenerator;


import jakarta.inject.Singleton;

import java.util.UUID;

@Singleton
public class RandomIdGenerator implements IdGenerator {

    public String generate() {
        return UUID.randomUUID().toString();
    }

}
