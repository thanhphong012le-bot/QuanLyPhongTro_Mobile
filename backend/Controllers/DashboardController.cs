using Microsoft.AspNetCore.Mvc;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;
using System.Linq;
using Microsoft.AspNetCore.Http;

namespace quanlyphongtro.Controllers
{
    public class DashboardController : Controller
    {
        private readonly ApplicationDbContext _context;

        public DashboardController(ApplicationDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            if (_context.Rooms == null) return Problem("Dữ liệu trống.");

            // Tính toán dữ liệu
            var totalRooms = _context.Rooms.Count();
            var rentedRooms = _context.Rooms.Count(r => r.Status == false);
            var emptyRooms = _context.Rooms.Count(r => r.Status == true);
            var totalMoney = _context.Rooms.Where(r => r.Status == false).Sum(r => r.Price);

            // Gửi dữ liệu qua ViewBag
            ViewBag.TotalRooms = totalRooms;
            ViewBag.RentedRooms = rentedRooms;
            ViewBag.EmptyRooms = emptyRooms;
            ViewBag.TotalTenants = rentedRooms;
            ViewBag.TotalMoney = totalMoney;

            return View(); // Lệnh này sẽ mở file Index.cshtml bên dưới
        }
    }
}