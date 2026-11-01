using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;


namespace quanlyphongtro.Controllers
{
    public class InvoicesController : Controller
    {
        private readonly ApplicationDbContext _context;

        public InvoicesController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. DANH SÁCH HÓA ĐƠN
        public async Task<IActionResult> Index()
        {
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            var username = HttpContext.Session.GetString("User");

            if (string.IsNullOrEmpty(role)) return RedirectToAction("Login", "Account");

            IQueryable<Invoice> query = _context.Invoices.Include(i => i.Room);

            // PHÂN QUYỀN LỌC: User chỉ thấy của mình, Owner/Manager thấy hết
            if (role == "user" || role == "tenant")
            {
                var userRecord = await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
                if (userRecord != null && userRecord.RoomId != null)
                {
                    query = query.Where(i => i.RoomId == userRecord.RoomId);
                }
                else
                {
                    query = query.Where(i => false);
                }
            }

            var invoices = await query
                .OrderByDescending(i => i.Year)
                .ThenByDescending(i => i.Month)
                .ToListAsync();

            return View(invoices);
        }

        // 2. GIAO DIỆN NHẬP CHỈ SỐ (GET)
        public async Task<IActionResult> Create(int roomId)
        {
            // THÊM CHỐT CHẶN: Chỉ Owner (A) và Manager (B) mới được nhập điện nước
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner" && role != "manager") return Content("Bạn không có quyền nhập điện nước!");

            var room = await _context.Rooms.FindAsync(roomId);
            if (room == null) return NotFound();

            var lastInvoice = await _context.Invoices
                .Where(i => i.RoomId == roomId)
                .OrderByDescending(i => i.Id)
                .FirstOrDefaultAsync();

            var model = new Invoice
            {
                RoomId = roomId,
                Room = room,
                Month = DateTime.Now.Month,
                Year = DateTime.Now.Year,
                ElectricOld = lastInvoice?.ElectricNew ?? 0,
                WaterOld = lastInvoice?.WaterNew ?? 0
            };

            return View(model);
        }

        // 3. XỬ LÝ LƯU HÓA ĐƠN & TÍNH TIỀN (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Invoice invoice)
        {
            // THÊM CHỐT CHẶN BẢO MẬT POST
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner" && role != "manager") return Content("Hành động không được phép!");

            var room = await _context.Rooms.FindAsync(invoice.RoomId);
            if (room == null) return NotFound();

            decimal tienDien = (invoice.ElectricNew - invoice.ElectricOld) * room.ElectricPrice;
            decimal tienNuoc = (invoice.WaterNew - invoice.WaterOld) * room.WaterPrice;
            decimal tienWifi = room.HasWifi ? room.WifiPrice : 0;
            decimal tienRac = room.TrashPrice;

            invoice.TotalAmount = room.Price + tienDien + tienNuoc + tienWifi + tienRac;
            invoice.CreatedDate = DateTime.Now;
            invoice.IsPaid = false;

            _context.Add(invoice);
            await _context.SaveChangesAsync();
            return RedirectToAction(nameof(Index));
        }

        // 4. CHI TIẾT HÓA ĐƠN
        public async Task<IActionResult> Details(int id)
        {
            var invoice = await _context.Invoices
                .Include(i => i.Room)
                .FirstOrDefaultAsync(m => m.Id == id);

            if (invoice == null) return NotFound();

            return View(invoice);
        }

        // 5. USER XÁC NHẬN THANH TOÁN
        [HttpPost]
        public async Task<IActionResult> ConfirmPaymentAjax(int id)
        {
            var invoice = await _context.Invoices.FindAsync(id);
            if (invoice != null)
            {
                invoice.IsPaid = true;
                await _context.SaveChangesAsync();
                return Json(new { success = true });
            }
            return Json(new { success = false, message = "Không tìm thấy hóa đơn" });
        }

        // 6. ADMIN XÁC NHẬN THANH TOÁN
        [HttpPost]
        public async Task<IActionResult> AdminVerify(int id)
        {
            // CHỈ OWNER MỚI ĐƯỢC XÁC NHẬN CUỐI CÙNG
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner" && role != "manager") return Content("Bạn không có quyền xác nhận!");

            var invoice = await _context.Invoices.FindAsync(id);
            if (invoice != null)
            {
                invoice.IsPaid = true;
                await _context.SaveChangesAsync();
            }
            return RedirectToAction(nameof(Index));
        }
    }
}