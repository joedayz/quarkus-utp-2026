package edu.utp.quarkus.student;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;

@Entity
public class Student extends PanacheEntity {

    @Column(nullable = false, unique = true)
    public String code;

    @Column(nullable = false)
    public String fullName;

    public String email;

    public String career;
}

