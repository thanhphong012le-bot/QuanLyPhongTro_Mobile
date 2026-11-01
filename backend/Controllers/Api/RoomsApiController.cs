using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;
using quanlyphongtro.Models.Api;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/rooms")]
    public class RoomsApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public RoomsApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        private string? Role => HttpContext.Session.GetString("Role")?.ToLower();
        private bool LoggedIn => HttpContext.Session.GetString("User") != null;

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });

            var rooms = await _context.Rooms.AsNoTracking()
                .OrderBy(r => r.RoomName)
                .Select(r => new
                {
                    r.Id,
                    r.RoomName,
                    r.Price,
                    r.Status,
                    r.TenantUsername,
                    r.ElectricPrice,
                    r.WaterPrice,
                    r.WifiPrice,
                    r.HasWifi,
                    r.TrashPrice
                })
                .ToListAsync();

            return Ok(rooms);
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });

            var room = await _context.Rooms.AsNoTracking()
                .Where(r => r.Id == id)
                .Select(r => new
                {
                    r.Id,
                    r.RoomName,
                    r.Price,
                    r.Status,
                    r.TenantUsername,
                    r.ElectricPrice,
                    r.WaterPrice,
                    r.WifiPrice,
                    r.HasWifi,
                    r.TrashPrice
                })
                .FirstOrDefaultAsync();

            return room == null ? NotFound(new { message = "Không tìm thấy phòng." }) : Ok(room);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] RoomRequest request)
        {
            if (Role != "owner")
                return StatusCode(403, new { message = "Chỉ Chủ nhà mới có quyền thêm phòng." });

            var room = new Room
            {
                RoomName = request.RoomName,
                Price = request.Price,
                Status = request.Status,
                TenantUsername = request.TenantUsername,
                ElectricPrice = request.ElectricPrice,
                WaterPrice = request.WaterPrice,
                WifiPrice = request.WifiPrice,
                HasWifi = request.HasWifi,
                TrashPrice = request.TrashPrice
            };

            _context.Rooms.Add(room);
            await _context.SaveChangesAsync();
            return CreatedAtAction(nameof(GetById), new { id = room.Id }, room);
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(int id, [FromBody] RoomRequest request)
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền sửa phòng." });

            var room = await _context.Rooms.FindAsync(id);
            if (room == null) return NotFound(new { message = "Không tìm thấy phòng." });

            room.RoomName = request.RoomName;
            room.Price = request.Price;
            room.Status = request.Status;
            room.TenantUsername = request.TenantUsername;
            room.ElectricPrice = request.ElectricPrice;
            room.WaterPrice = request.WaterPrice;
            room.WifiPrice = request.WifiPrice;
            room.HasWifi = request.HasWifi;
            room.TrashPrice = request.TrashPrice;

            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            if (Role != "owner")
                return StatusCode(403, new { message = "Chỉ Chủ nhà mới có quyền xóa phòng." });

            var room = await _context.Rooms.FindAsync(id);
            if (room == null) return NotFound(new { message = "Không tìm thấy phòng." });

            _context.Rooms.Remove(room);
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }
    }
}
