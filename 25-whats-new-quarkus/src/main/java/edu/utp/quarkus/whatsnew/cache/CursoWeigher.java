package edu.utp.quarkus.whatsnew.cache;

import com.github.benmanes.caffeine.cache.Weigher;
import edu.utp.quarkus.whatsnew.model.Curso;

/**
 * Weigher usado por la region "cursos" de la cache L2 de Hibernate ORM.
 *
 * Novedad de Quarkus 3.38: antes solo existia eviccion basada en el numero de
 * objetos ({@code memory.object-count}). Ahora se puede asignar un peso real a
 * cada entrada (por ejemplo, el tamano estimado en bytes de sus campos de texto)
 * y limitar la cache por {@code memory.maximum-weight} en lugar de por cantidad
 * de entidades, algo util cuando el tamano de las entidades es muy variable.
 *
 * Configurado en application.properties mediante:
 *   quarkus.hibernate-orm.cache."cursos".memory.maximum-weight=...
 *   quarkus.hibernate-orm.cache."cursos".memory.weigher-class=edu.utp.quarkus.whatsnew.cache.CursoWeigher
 */
public class CursoWeigher implements Weigher<Object, Object> {

    @Override
    public int weigh(Object key, Object value) {
        if (!(value instanceof Curso curso)) {
            return 1;
        }
        int nombreLength = curso.nombre != null ? curso.nombre.length() : 0;
        int descripcionLength = curso.descripcion != null ? curso.descripcion.length() : 0;
        // Peso aproximado en "unidades de caracteres" de los campos de texto del curso.
        return Math.max(1, nombreLength + descripcionLength);
    }
}
