package edu.utp.training.speaker;

import edu.utp.training.speaker.idgenerator.IdGenerator;

import java.util.UUID;



public class DeterministicIdGenerator implements IdGenerator {

    private UUID nextUUID = new UUID( 0, 0 );

    public String generate() {
        UUID result = nextUUID;
        nextUUID = null;
        return result.toString();
    }

    public void setNextUUID( final UUID nextUUID ) {
        this.nextUUID = nextUUID;
    }

}