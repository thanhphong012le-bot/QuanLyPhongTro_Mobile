using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models.Api;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/auth")]
    public class AuthApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public AuthApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
                return BadRequest(new { message = "Vui lòng nhập tài khoản và mật khẩu." });

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Username == request.Username && u.Password == request.Password);

            if (user == null)
                return Unauthorized(new { message = "Tài khoản hoặc mật khẩu không chính xác." });

            var role = (user.Role ?? "Tenant").Trim().ToLower();
            HttpContext.Session.SetString("User", user.Username);
            HttpContext.Session.SetString("Role", role);

            return Ok(new
            {
                success = true,
                user = new
                {
                    user.Id,
                    user.Username,
                    user.FullName,
                    role,
                    user.RoomId
                }
            });
        }

        [HttpGet("me")]
        public async Task<IActionResult> Me()
        {
            var username = HttpContext.Session.GetString("User");
            if (string.IsNullOrWhiteSpace(username))
                return Unauthorized(new { message = "Chưa đăng nhập." });

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Username == username);

            if (user == null)
                return Unauthorized(new { message = "Không tìm thấy tài khoản." });

            return Ok(new
            {
                user.Id,
                user.Username,
                user.FullName,
                role = (user.Role ?? "Tenant").Trim().ToLower(),
                user.RoomId
            });
        }

        [HttpPost("logout")]
        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return Ok(new { success = true });
        }
    }
}
