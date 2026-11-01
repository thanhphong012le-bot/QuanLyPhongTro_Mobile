using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;
using quanlyphongtro.Models.Api;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/invoices")]
    public class InvoicesApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public InvoicesApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        private string? Role => HttpContext.Session.GetString("Role")?.ToLower();
        private string? Username => HttpContext.Session.GetString("User");
        private bool LoggedIn => Username != null;

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });

            IQueryable<Invoice> query = _context.Invoices.AsNoTracking().Include(i => i.Room);

            if (Role == "tenant" || Role == "user")
            {
                var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Username == Username);
                if (user?.RoomId == null)
                    query = query.Where(i => false);
                else
                    query = query.Where(i => i.RoomId == user.RoomId.Value);
            }

            var invoices = await query
                .OrderByDescending(i => i.Year)
                .ThenByDescending(i => i.Month)
                .Select(i => new
                {
                    i.Id,
                    i.RoomId,
                    roomName = i.Room != null ? i.Room.RoomName : null,
                    tenantUsername = i.Room != null ? i.Room.TenantUsername : null,
                    i.Month,
                    i.Year,
                    i.ElectricOld,
                    i.ElectricNew,
                    i.WaterOld,
                    i.WaterNew,
                    i.IsPaid,
                    i.TotalAmount,
                    i.CreatedDate
                })
                .ToListAsync();

            return Ok(invoices);
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });

            var invoice = await _context.Invoices.AsNoTracking()
                .Include(i => i.Room)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (invoice == null) return NotFound(new { message = "Không tìm thấy hóa đơn." });

            if (Role == "tenant" || Role == "user")
            {
                var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Username == Username);
                if (user?.RoomId != invoice.RoomId)
                    return StatusCode(403, new { message = "Bạn không có quyền xem hóa đơn này." });
            }

            return Ok(new
            {
                invoice.Id,
                invoice.RoomId,
                roomName = invoice.Room?.RoomName,
                tenantUsername = invoice.Room?.TenantUsername,
                invoice.Month,
                invoice.Year,
                invoice.ElectricOld,
                invoice.ElectricNew,
                invoice.WaterOld,
                invoice.WaterNew,
                invoice.IsPaid,
                invoice.TotalAmount,
                invoice.CreatedDate
            });
        }

        [HttpGet("last-readings/{roomId:int}")]
        public async Task<IActionResult> GetLastReadings(int roomId)
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền nhập điện nước." });

            var room = await _context.Rooms.AsNoTracking().FirstOrDefaultAsync(r => r.Id == roomId);
            if (room == null) return NotFound(new { message = "Không tìm thấy phòng." });

            var last = await _context.Invoices.AsNoTracking()
                .Where(i => i.RoomId == roomId)
                .OrderByDescending(i => i.Year)
                .ThenByDescending(i => i.Month)
                .ThenByDescending(i => i.Id)
                .FirstOrDefaultAsync();

            return Ok(new
            {
                roomId,
                roomName = room.RoomName,
                tenantUsername = room.TenantUsername,
                electricOld = last?.ElectricNew ?? 0,
                waterOld = last?.WaterNew ?? 0,
                month = DateTime.Now.Month,
                year = DateTime.Now.Year
            });
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] InvoiceRequest request)
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền tạo hóa đơn." });

            if (request.Month < 1 || request.Month > 12 || request.Year < 2000 || request.Year > 2100)
                return BadRequest(new { message = "Tháng hoặc năm không hợp lệ." });

            var room = await _context.Rooms.FindAsync(request.RoomId);
            if (room == null) return NotFound(new { message = "Không tìm thấy phòng." });

            bool duplicate = await _context.Invoices.AnyAsync(i =>
                i.RoomId == request.RoomId &&
                i.Month == request.Month &&
                i.Year == request.Year);
            if (duplicate)
                return BadRequest(new { message = $"Phòng {room.RoomName} đã có hóa đơn tháng {request.Month}/{request.Year}." });

            if (request.ElectricNew < request.ElectricOld || request.WaterNew < request.WaterOld)
                return BadRequest(new { message = "Chỉ số mới không được nhỏ hơn chỉ số cũ." });

            int electricUnits = request.ElectricNew - request.ElectricOld;
            int waterUnits = request.WaterNew - request.WaterOld;
            decimal electricity = electricUnits * room.ElectricPrice;
            decimal water = waterUnits * room.WaterPrice;
            decimal wifi = room.HasWifi ? room.WifiPrice : 0;
            decimal trash = room.TrashPrice;
            decimal total = room.Price + electricity + water + wifi + trash;

            var invoice = new Invoice
            {
                RoomId = request.RoomId,
                Month = request.Month,
                Year = request.Year,
                ElectricOld = request.ElectricOld,
                ElectricNew = request.ElectricNew,
                WaterOld = request.WaterOld,
                WaterNew = request.WaterNew,
                TotalAmount = total,
                CreatedDate = DateTime.Now,
                IsPaid = false
            };

            _context.Invoices.Add(invoice);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                invoice.Id,
                roomId = room.Id,
                roomName = room.RoomName,
                tenantUsername = room.TenantUsername,
                electricUnits,
                waterUnits,
                electricity,
                water,
                roomPrice = room.Price,
                wifi,
                trash,
                totalAmount = total
            });
        }

        [HttpPost("{id:int}/pay")]
        public async Task<IActionResult> ConfirmPayment(int id)
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });

            var invoice = await _context.Invoices.FindAsync(id);
            if (invoice == null) return NotFound(new { message = "Không tìm thấy hóa đơn." });

            if (Role == "tenant" || Role == "user")
            {
                var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Username == Username);
                if (user?.RoomId != invoice.RoomId)
                    return StatusCode(403, new { message = "Bạn không có quyền xác nhận hóa đơn này." });
            }

            invoice.IsPaid = true;
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }
    }
}
