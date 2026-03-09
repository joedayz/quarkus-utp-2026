package edu.utp.training;


import java.util.List;
import java.util.ArrayList;
import java.util.stream.Collectors;

import edu.utp.training.entities.WeatherWarning;
import jakarta.enterprise.context.ApplicationScoped;


@ApplicationScoped
public class WeatherWarningsRepository {

    private List<WeatherWarning> warnings;

    WeatherWarningsRepository() {
        clear();
    }

    public List<WeatherWarning> all() {
        return warnings;
    }

    public List<WeatherWarning> listByCity(String city) {
        return warnings.stream()
                .filter(p -> p.city.equalsIgnoreCase(city))
                .collect(Collectors.toList());
    }

    public WeatherWarning add( WeatherWarning warning ) {
        warnings.add( warning );
        return warning;
    }

    public void clear() {
        warnings = new ArrayList<WeatherWarning>();
    }
}
