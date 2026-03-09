package edu.utp.training;

import jakarta.persistence.Entity;



@Entity
public class Suggestion extends PanacheEntity {
    public Long clientId;
    public Long itemId;

    public Suggestion() {
    }

    public Suggestion( Long clientId, Long itemId ) {
        this.clientId = clientId;
        this.itemId = itemId;
    }
}
