package edu.utp.quarkus.genai.dto;

import java.util.List;

public record ScheduleResponse(String question, String answer, String model, int cursosConsultados) {
}
