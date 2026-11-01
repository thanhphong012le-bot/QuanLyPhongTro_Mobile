using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;
using quanlyphongtro.Models.Api;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/users")]
    public class UsersApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public UsersApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        private bool IsOwner => HttpContext.Session.GetString("Role")?.ToLower() == "owner";

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            if (!IsOwner) return StatusCode(403, new { message = "Chỉ Chủ nhà được quản lý tài khoản." });

            var users = await _context.Users.AsNoTracking()
                .Include(u => u.Room)
                .OrderBy(u => u.Username)
                .Select(u => new
                {
                    u.Id,
                    u.Username,
                    u.FullName,
                    u.Role,
                    u.RoomId,
                    roomName = u.Room != null ? u.Room.RoomName : null
                })
                .ToListAsync();

            return Ok(users);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] UserRequest request)
        {
            if (!IsOwner) return StatusCode(403, new { message = "Chỉ Chủ nhà được tạo tài khoản." });
            if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
                return BadRequest(new { message = "Vui lòng nhập tài khoản và mật khẩu." });

            if (await _context.Users.AnyAsync(u => u.Username == request.Username))
                return BadRequest(new { message = "Tên đăng nhập này đã tồn tại." });

            var user = new User
            {
                Username = request.Username.Trim(),
                Password = request.Password,
                FullName = request.FullName,
                Role = string.IsNullOrWhiteSpace(request.Role) ? "Tenant" : request.Role,
                RoomId = request.RoomId
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            if (user.Role.Equals("Tenant", StringComparison.OrdinalIgnoreCase) && user.RoomId != null)
            {
                var room = await _context.Rooms.FindAsync(user.RoomId.Value);
                if (room != null)
                {
                    room.Status = false;
                    room.TenantUsername = user.Username;
                    await _context.SaveChangesAsync();
                }
            }

            return Ok(new { success = true, user.Id });
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(int id, [FromBody] UserRequest request)
        {
            if (!IsOwner) return StatusCode(403, new { message = "Chỉ Chủ nhà được sửa tài khoản." });

            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound(new { message = "Không tìm thấy tài khoản." });

            var duplicate = await _context.Users.AnyAsync(u => u.Username == request.Username && u.Id != id);
            if (duplicate) return BadRequest(new { message = "Tên đăng nhập này đã tồn tại." });

            user.Username = request.Username.Trim();
            if (!string.IsNullOrWhiteSpace(request.Password)) user.Password = request.Password;
            user.FullName = request.FullName;
            user.Role = string.IsNullOrWhiteSpace(request.Role) ? "Tenant" : request.Role;
            user.RoomId = request.RoomId;

            await _context.SaveChangesAsync();

            if (user.Role.Equals("Tenant", StringComparison.OrdinalIgnoreCase) && user.RoomId != null)
            {
                var room = await _context.Rooms.FindAsync(user.RoomId.Value);
                if (room != null)
                {
                    room.Status = false;
                    room.TenantUsername = user.Username;
                    await _context.SaveChangesAsync();
                }
            }

            return Ok(new { success = true });
        }
    }
}
