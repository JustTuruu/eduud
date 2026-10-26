package mn.eduud.common;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Array;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import org.postgresql.util.PGobject;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

/**
 * Prisma-гийн буцаадаг JSON хэлбэрийг давтах туслах:
 * snake_case баганыг camelCase түлхүүр болгож, Timestamp -> Instant,
 * text[] -> List, json/jsonb -> JsonNode болгоно.
 */
@Component
public class Rows {
  private final ObjectMapper mapper;

  public Rows(ObjectMapper mapper) {
    this.mapper = mapper;
  }

  public RowMapper<Map<String, Object>> camel() {
    return this::mapRow;
  }

  public Map<String, Object> mapRow(ResultSet rs, int rowNum) throws SQLException {
    ResultSetMetaData md = rs.getMetaData();
    Map<String, Object> m = new LinkedHashMap<>();
    for (int i = 1; i <= md.getColumnCount(); i++) {
      m.put(camel(md.getColumnLabel(i)), convert(rs.getObject(i)));
    }
    return m;
  }

  public Object convert(Object v) throws SQLException {
    if (v == null) return null;
    if (v instanceof Timestamp t) return t.toInstant();
    if (v instanceof Array a) return Arrays.asList((Object[]) a.getArray());
    if (v instanceof PGobject pg && pg.getType() != null && pg.getType().startsWith("json")) {
      return parseJson(pg.getValue());
    }
    return v;
  }

  public JsonNode parseJson(String json) {
    if (json == null) return null;
    try {
      return mapper.readTree(json);
    } catch (Exception e) {
      throw new IllegalStateException("JSON задлахад алдаа", e);
    }
  }

  public String toJson(Object value) {
    try {
      return value == null ? null : mapper.writeValueAsString(value);
    } catch (Exception e) {
      throw new IllegalStateException("JSON үүсгэхэд алдаа", e);
    }
  }

  public static String camel(String column) {
    StringBuilder sb = new StringBuilder(column.length());
    boolean up = false;
    for (char c : column.toCharArray()) {
      if (c == '_') {
        up = true;
      } else {
        sb.append(up ? Character.toUpperCase(c) : c);
        up = false;
      }
    }
    return sb.toString();
  }

  public static Timestamp ts(Instant i) {
    return i == null ? null : Timestamp.from(i);
  }
}
