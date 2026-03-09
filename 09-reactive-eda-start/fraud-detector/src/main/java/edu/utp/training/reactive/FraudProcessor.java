package edu.utp.training.reactive;


import edu.utp.training.event.BankAccountWasCreated;
import edu.utp.training.event.HighRiskAccountWasDetected;
import edu.utp.training.event.LowRiskAccountWasDetected;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;
import org.eclipse.microprofile.reactive.messaging.Incoming;
import org.eclipse.microprofile.reactive.messaging.Message;
import org.jboss.logging.Logger;

import java.util.concurrent.CompletionStage;

@ApplicationScoped
public class FraudProcessor {
    private static final Logger LOGGER = Logger.getLogger(FraudProcessor.class);

    private Integer calculateFraudScore(Long amount) {
        if (amount > 25000) {
            return 75;
        } else if (amount > 3000) {
            return 25;
        }

        return -1;
    }

    private void logBankAccountWasCreatedEvent(BankAccountWasCreated event) {
        LOGGER.infov(
                "Received BankAccountWasCreated - ID: {0} Balance: {1}",
                event.id,
                event.balance
        );
    }

    private void logFraudScore(Long bankAccountId, Integer score) {
        LOGGER.infov(
                "Fraud score was calculated - ID: {0} Score: {1}",
                bankAccountId,
                score
        );
    }

    private void logEmitEvent(String eventName, Long bankAccountId) {
        LOGGER.infov(
                "Sending a {0} event for bank account #{1}",
                eventName,
                bankAccountId
        );
    }
}
