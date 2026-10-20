import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

/**
 * Socket.IO gateway.
 * - Auction үзэх нь нээлттэй: client `join_auction`-оор room-д орно.
 * - Handshake-д JWT (auth.token) өгвөл хувийн `user:{id}` room-д автоматаар орно
 *   (wallet_updated, won гэх мэт хувийн event хүлээж авахад).
 * Event бүрт serverTime дагалдуулж клиент clock offset-оо засна.
 */
@WebSocketGateway({ cors: { origin: true } })
export class RealtimeGateway implements OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server: Server;

  constructor(private readonly jwt: JwtService) {}

  async handleConnection(client: Socket) {
    const token = client.handshake.auth?.token as string | undefined;
    if (token) {
      try {
        const payload = await this.jwt.verifyAsync(token, {
          secret: process.env.JWT_ACCESS_SECRET,
        });
        client.data.userId = payload.sub;
        await client.join(`user:${payload.sub}`);
      } catch {
        // Токен хүчингүй бол зөвхөн нээлттэй room-ууд үзнэ
      }
    }
  }

  @SubscribeMessage('join_auction')
  async joinAuction(@ConnectedSocket() client: Socket, @MessageBody() body: { auctionId: string }) {
    if (body?.auctionId) await client.join(`auction:${body.auctionId}`);
    return { ok: true, serverTime: Date.now() };
  }

  @SubscribeMessage('leave_auction')
  async leaveAuction(@ConnectedSocket() client: Socket, @MessageBody() body: { auctionId: string }) {
    if (body?.auctionId) await client.leave(`auction:${body.auctionId}`);
    return { ok: true };
  }

  // ---------- Server -> client broadcast helpers ----------

  emitToAuction(auctionId: string, event: string, payload: object) {
    this.server?.to(`auction:${auctionId}`).emit(event, { ...payload, serverTime: Date.now() });
  }

  emitToUser(userId: string, event: string, payload: object) {
    this.server?.to(`user:${userId}`).emit(event, { ...payload, serverTime: Date.now() });
  }
}
