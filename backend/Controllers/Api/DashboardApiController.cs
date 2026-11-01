using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/dashboard")]
    public class DashboardApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public DashboardApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetDashboard()
        {
            if (HttpContext.Session.GetString("User") == null)
                return Unauthorized(new { message = "Chưa đăng nhập." });

            var totalRooms = await _context.Rooms.CountAsync();
            var rentedRooms = await _context.Rooms.CountAsync(r => r.Status == false);
            var emptyRooms = await _context.Rooms.CountAsync(r => r.Status == true);
            var totalMoney = await _context.Rooms
                .Where(r => r.Status == false)
                .SumAsync(r => (decimal?)r.Price) ?? 0;
            var unpaidInvoices = await _context.Invoices.CountAsync(i => !i.IsPaid);

            return Ok(new
            {
                totalRooms,
                rentedRooms,
                emptyRooms,
                totalTenants = rentedRooms,
                totalMoney,
                unpaidInvoices
            });
        }
    }
}
