package mn.eduud.realtime;

import com.corundumstudio.socketio.AuthTokenResult;
import com.corundumstudio.socketio.Configuration;
import com.corundumstudio.socketio.SocketConfig;
import com.corundumstudio.socketio.SocketIOClient;
import com.corundumstudio.socketio.SocketIOServer;
import com.corundumstudio.socketio.Transport;
import com.corundumstudio.socketio.namespace.Namespace;
import io.jsonwebtoken.Claims;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.util.LinkedHashMap;
import java.util.Map;
import mn.eduud.common.auth.JwtService;
import mn.eduud.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Socket.IO v4 сервер (netty-socketio). NestJS-ийн RealtimeGateway-тэй ижил:
 * - `join_auction` / `leave_auction` -> `auction:{id}` room
 * - Handshake-д auth.token (JWT) өгвөл `user:{id}` room-д автоматаар орно
 * - Event бүрт serverTime дагалдана (клиент clock offset-оо засна)
 *
 * Анхаар: netty-socketio тусдаа портон дээр (SOCKET_PORT, анхдагч 3001) ажиллана.
 * Flutter-д --dart-define=SOCKET_URL=http://host:3001 өгнө.
 */
@Component
public class RealtimeGateway {
  private static final Logger log = LoggerFactory.getLogger(RealtimeGateway.class);

  private final JwtService jwt;
  private final int port;
  private SocketIOServer server;

  private final boolean enabled;

  public RealtimeGateway(
      JwtService jwt,
      AppProperties props,
      @org.springframework.beans.factory.annotation.Value("${app.runtime-enabled:true}") boolean enabled) {
    this.jwt = jwt;
    this.port = props.socket().port();
    this.enabled = enabled;
  }

  @PostConstruct
  void start() {
    if (!enabled) return;
    Configuration config = new Configuration();
    // Container дотор бүх интерфейс дээр сонсох шаардлагатай тул зориудаар 0.0.0.0
    config.setHostname("0.0.0.0"); // NOPMD - AvoidUsingHardCodedIP
    config.setPort(port);
    config.setOrigin("*");
    config.setTransports(Transport.WEBSOCKET, Transport.POLLING);
    SocketConfig socketConfig = new SocketConfig();
    socketConfig.setReuseAddress(true);
    config.setSocketConfig(socketConfig);

    server = new SocketIOServer(config);
    // Socket.IO v4: handshake-ийн `auth` өгөгдөл CONNECT packet-аар ирдэг тул энд уншина
    ((Namespace) server.getNamespace(Namespace.DEFAULT_NAME))
        .addAuthTokenListener(
            (authData, client) -> {
              joinUserRoom(client, tokenFrom(authData));
              return AuthTokenResult.AuthTokenResultSuccess;
            });
    // Хуучин (v2) клиент: ?token=... query параметрээр
    server.addConnectListener(client -> {
      if (client.get("userId") == null) joinUserRoom(client, client.getHandshakeData().getSingleUrlParam("token"));
    });
    server.addEventListener(
        "join_auction",
        Map.class,
        (client, data, ack) -> {
          Object auctionId = data == null ? null : data.get("auctionId");
          if (auctionId != null) client.joinRoom("auction:" + auctionId);
          if (ack.isAckRequested()) ack.sendAckData(Map.of("ok", true, "serverTime", System.currentTimeMillis()));
        });
    server.addEventListener(
        "leave_auction",
        Map.class,
        (client, data, ack) -> {
          Object auctionId = data == null ? null : data.get("auctionId");
          if (auctionId != null) client.leaveRoom("auction:" + auctionId);
          if (ack.isAckRequested()) ack.sendAckData(Map.of("ok", true));
        });
    server.start();
    log.info("Socket.IO listening on :{}", port);
  }

  private void joinUserRoom(SocketIOClient client, String token) {
    if (token == null || token.isEmpty()) return;
    try {
      Claims c = jwt.verify(token);
      client.set("userId", c.getSubject());
      client.joinRoom("user:" + c.getSubject());
    } catch (Exception ignored) {
      // Токен хүчингүй бол зөвхөн нээлттэй room-ууд үзнэ
    }
  }

  private static String tokenFrom(Object authData) {
    if (authData instanceof Map<?, ?> m && m.get("token") != null) return String.valueOf(m.get("token"));
    return null;
  }

  @PreDestroy
  void stop() {
    if (server != null) server.stop();
  }

  // ---------- Server -> client broadcast helpers ----------

  public void emitToAuction(String auctionId, String event, Map<String, Object> payload) {
    if (server != null) server.getRoomOperations("auction:" + auctionId).sendEvent(event, withTime(payload));
  }

  public void emitToUser(String userId, String event, Map<String, Object> payload) {
    if (server != null) server.getRoomOperations("user:" + userId).sendEvent(event, withTime(payload));
  }

  private static Map<String, Object> withTime(Map<String, Object> payload) {
    Map<String, Object> m = new LinkedHashMap<>(payload);
    m.put("serverTime", System.currentTimeMillis());
    return m;
  }
}
