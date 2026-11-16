package mn.eduud.payments;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Map;
import mn.eduud.common.Rows;
import mn.eduud.realtime.RealtimeGateway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Lab 10: PaymentsService.settle() — idempotency guard-ыг DB-гүйгээр (Mockito mock) шалгана.
 * JdbcClient-ийн fluent API-г RETURNS_DEEP_STUBS-ээр орлуулна.
 */
class PaymentsServiceTest {
  private JdbcClient db;
  private Rows rows;
  private TransactionTemplate tx;
  private WireService wire;
  private RealtimeGateway realtime;
  private PaymentsService service;

  @BeforeEach
  @SuppressWarnings("unchecked")
  void setUp() {
    db = mock(JdbcClient.class, RETURNS_DEEP_STUBS);
    rows = mock(Rows.class);
    tx = mock(TransactionTemplate.class);
    wire = mock(WireService.class);
    realtime = mock(RealtimeGateway.class);
    // Транзакцийн callback-ийг шууд ажиллуулна
    when(tx.execute(any()))
        .thenAnswer(inv -> ((TransactionCallback<Object>) inv.getArgument(0)).doInTransaction(null));
    service = new PaymentsService(db, rows, tx, wire, realtime);
  }

  @Test
  void settle_alreadyPaid_updateAffectsZeroRows_noSideEffects() {
    // Arrange: UPDATE ... WHERE status = 'pending' нь 0 мөр өөрчилнө (давхар webhook)
    when(db.sql(contains("UPDATE payments")).params(any(Object[].class)).update()).thenReturn(0);

    // Act
    Map<String, Object> result = service.settle("pay-1", Map.of("k", "v"));

    // Assert: token нэмэгдэхгүй, socket event явахгүй, хариу нь ok
    assertThat(result).containsEntry("ok", true);
    verify(db, never()).sql(contains("UPDATE wallets"));
    verify(db, never()).sql(contains("INSERT INTO token_transactions"));
    verify(realtime, never()).emitToUser(anyString(), anyString(), any());
  }

  @Test
  void settle_topupPending_creditsWalletAndEmitsBalance() {
    // Arrange
    when(db.sql(contains("UPDATE payments")).params(any(Object[].class)).update()).thenReturn(1);
    Map<String, Object> payment = new java.util.HashMap<>();
    payment.put("userId", "u1");
    payment.put("kind", "topup");
    payment.put("orderId", null);
    payment.put("tokens", 50);
    when(db.sql(contains("SELECT p.user_id")).param(any()).query(any(org.springframework.jdbc.core.RowMapper.class)).single())
        .thenReturn(payment);
    when(db.sql(contains("UPDATE wallets")).params(any(Object[].class)).query(Integer.class).single())
        .thenReturn(150);
    when(db.sql(contains("INSERT INTO token_transactions")).params(any(Object[].class)).update()).thenReturn(1);

    // Act
    Map<String, Object> result = service.settle("pay-1", null);

    // Assert
    assertThat(result).containsEntry("ok", true);
    verify(realtime).emitToUser("u1", "wallet_updated", Map.of("balance", 150));
  }

  @Test
  void settle_calledTwice_secondCallDoesNotEmitAgain() {
    // Arrange: эхний удаа 1 мөр, хоёр дахь удаа 0 мөр өөрчлөгдөнө
    when(db.sql(contains("UPDATE payments")).params(any(Object[].class)).update()).thenReturn(1, 0);
    Map<String, Object> payment = new java.util.HashMap<>();
    payment.put("userId", "u1");
    payment.put("kind", "order");
    payment.put("orderId", "o1");
    when(db.sql(contains("SELECT p.user_id")).param(any()).query(any(org.springframework.jdbc.core.RowMapper.class)).single())
        .thenReturn(payment);

    // Act
    service.settle("pay-1", null);
    service.settle("pay-1", null);

    // Assert: order_paid зөвхөн нэг удаа
    verify(realtime, org.mockito.Mockito.times(1)).emitToUser(anyString(), anyString(), any());
  }
}
