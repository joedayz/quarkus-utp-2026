package edu.utp.training.event;

import edu.utp.training.model.Affiliation;

public class SpeakerWasCreated {
    public Long id;

    public String fullName;

    public Affiliation affiliation;

    public String email;

    public SpeakerWasCreated() {}

    public SpeakerWasCreated(Long id, String fullName, Affiliation affiliation, String email) {
        this.id = id;
        this.fullName = fullName;
        this.affiliation = affiliation;
        this.email = email;
    }
}

