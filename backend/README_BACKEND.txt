BACKEND MOBILE API
==================

Da them cac endpoint:
POST   /api/auth/login
GET    /api/auth/me
POST   /api/auth/logout
GET    /api/dashboard
GET    /api/rooms
GET    /api/rooms/{id}
POST   /api/rooms
PUT    /api/rooms/{id}
DELETE /api/rooms/{id}
GET    /api/invoices
GET    /api/invoices/{id}
GET    /api/invoices/last-readings/{roomId}
POST   /api/invoices
POST   /api/invoices/{id}/pay
GET    /api/contracts
POST   /api/contracts
POST   /api/contracts/{id}/approve
DELETE /api/contracts/{id}
GET    /api/users
POST   /api/users
PUT    /api/users/{id}

Chay cho Android Emulator / dien thoai:
  dotnet run --urls "http://0.0.0.0:5129"

Website cu van truy cap:
  http://localhost:5129
