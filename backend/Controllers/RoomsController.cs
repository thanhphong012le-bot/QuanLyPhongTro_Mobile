using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;

namespace quanlyphongtro.Controllers
{
    public class RoomsController : Controller
    {
        private readonly ApplicationDbContext _context;

        public RoomsController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. TRANG DANH SÁCH PHÒNG
        public async Task<IActionResult> Index()
        {
            if (HttpContext.Session.GetString("User") == null) return RedirectToAction("Login", "Account");
            var rooms = await _context.Rooms.ToListAsync();
            return View(rooms);
        }

        // 1.5. CHI TIẾT PHÒNG
        public async Task<IActionResult> Details(int? id)
        {
            if (id == null) return NotFound();
            var room = await _context.Rooms.FirstOrDefaultAsync(m => m.Id == id);
            if (room == null) return NotFound();
            return View(room);
        }

        // 2. TẠO PHÒNG (GET)
        public IActionResult Create()
        {
            // SỬA TẠI ĐÂY: Dùng ToLower() để khớp với Session lúc đăng nhập
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner") return Content("Chỉ Chủ nhà mới có quyền thêm phòng!");
            return View();
        }

        // 3. TẠO PHÒNG (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Room room)
        {
            if (ModelState.IsValid)
            {
                _context.Add(room);
                await _context.SaveChangesAsync();
                return RedirectToAction(nameof(Index));
            }
            return View(room);
        }

        // 4. SỬA PHÒNG (GET)
        public async Task<IActionResult> Edit(int? id)
        {
            // Đồng bộ chữ thường
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner" && role != "manager") return Content("Bạn không có quyền sửa!");

            if (id == null) return NotFound();
            var room = await _context.Rooms.FindAsync(id);
            if (room == null) return NotFound();
            return View(room);
        }

        // 5. SỬA PHÒNG (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, Room room)
        {
            if (id != room.Id) return NotFound();

            if (ModelState.IsValid)
            {
                try
                {
                    _context.Update(room);
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateConcurrencyException)
                {
                    if (!RoomExists(room.Id)) return NotFound();
                    else throw;
                }
                return RedirectToAction(nameof(Index));
            }
            return View(room);
        }

        // 6. XÓA PHÒNG (GET - Xác nhận)
        public async Task<IActionResult> Delete(int? id)
        {
            // SỬA TẠI ĐÂY: Đồng bộ chữ thường
            var role = HttpContext.Session.GetString("Role")?.ToLower();
            if (role != "owner") return Content("Chỉ Chủ nhà mới có quyền xóa!");

            if (id == null) return NotFound();
            var room = await _context.Rooms.FirstOrDefaultAsync(m => m.Id == id);
            if (room == null) return NotFound();
            return View(room);
        }

        // 6. XÓA PHÒNG (POST - Thực thi)
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            var room = await _context.Rooms.FindAsync(id);
            if (room != null)
            {
                _context.Rooms.Remove(room);
                await _context.SaveChangesAsync();
                TempData["SuccessMessage"] = $"Đã xóa phòng '{room.RoomName}' thành công!";
            }
            return RedirectToAction(nameof(Index));
        }

        private bool RoomExists(int id)
        {
            return _context.Rooms.Any(e => e.Id == id);
        }
    }
}