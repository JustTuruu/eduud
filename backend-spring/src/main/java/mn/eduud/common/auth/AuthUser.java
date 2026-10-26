package mn.eduud.common.auth;

public record AuthUser(String id, String role) {
  public boolean isAdmin() {
    return "admin".equals(role);
  }
}
