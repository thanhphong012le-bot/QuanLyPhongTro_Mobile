using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;

namespace quanlyphongtro.Controllers
{
    public class UsersController : Controller
    {
        private readonly ApplicationDbContext _context;

        public UsersController(ApplicationDbContext context)
        {
            _context = context;
        }

        // Hàm hỗ trợ kiểm tra quyền Owner (viết gọn để dùng lại)
        private bool IsOwner()
        {
            return HttpContext.Session.GetString("Role")?.ToLower() == "owner";
        }

        // 1. DANH SÁCH TÀI KHOẢN
        public async Task<IActionResult> Index()
        {
            if (!IsOwner()) return Content("Cấm truy cập");

            var users = await _context.Users.Include(u => u.Room).ToListAsync();
            return View(users);
        }

        // 2. TẠO TÀI KHOẢN MỚI (GET)
        public IActionResult Create()
        {
            if (!IsOwner()) return Content("Cấm truy cập");

            ViewBag.Rooms = new SelectList(_context.Rooms.ToList(), "Id", "RoomName");
            return View();
        }

        // 3. TẠO TÀI KHOẢN MỚI (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(User user)
        {
            // Bỏ qua check ModelState để ép Server nhận dữ liệu từ Form
            if (user != null)
            {
                // Kiểm tra xem tên đăng nhập đã bị trùng chưa
                var isExist = await _context.Users.AnyAsync(u => u.Username == user.Username);
                if (isExist)
                {
                    ModelState.AddModelError("", "Tên đăng nhập này đã tồn tại!");
                    ViewBag.Rooms = new SelectList(_context.Rooms.ToList(), "Id", "RoomName");
                    return View(user);
                }

                // Lưu User mới vào Database
                _context.Add(user);
                await _context.SaveChangesAsync();

                // Nếu là Tenant và có chọn phòng, tự động đổi trạng thái phòng thành "Đã thuê" (false)
                if (user.Role == "Tenant" && user.RoomId != null)
                {
                    var room = await _context.Rooms.FindAsync(user.RoomId);
                    if (room != null)
                    {
                        room.Status = false;
                        await _context.SaveChangesAsync();
                    }
                }

                return RedirectToAction(nameof(Index));
            }

            // Nếu có lỗi, nạp lại danh sách phòng cho Dropdownlist
            ViewBag.Rooms = new SelectList(_context.Rooms.ToList(), "Id", "RoomName");
            return View(user);
        }

        // 4. CHỈNH SỬA TÀI KHOẢN (GET)
        public async Task<IActionResult> Edit(int? id)
        {
            // Kiểm tra quyền (đồng bộ viết thường)
            if (HttpContext.Session.GetString("Role")?.ToLower() != "owner") return Content("Cấm truy cập");

            if (id == null) return NotFound();

            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();

            // Lấy danh sách phòng để đổ vào Dropdown
            ViewBag.Rooms = new SelectList(_context.Rooms.ToList(), "Id", "RoomName", user.RoomId);
            return View(user);
        }

        // 5. CHỈNH SỬA TÀI KHOẢN (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, User user)
        {
            if (HttpContext.Session.GetString("Role")?.ToLower() != "owner") return Content("Cấm truy cập");

            if (id != user.Id) return NotFound();

            // Bỏ qua check ModelState để tránh kẹt lỗi Object Room
            try
            {
                // 1. Cập nhật thông tin User
                _context.Update(user);
                await _context.SaveChangesAsync();

                // 2. Logic tự động: Nếu gán phòng cho Tenant, đổi trạng thái phòng đó
                if (user.Role == "Tenant" && user.RoomId != null)
                {
                    var room = await _context.Rooms.FindAsync(user.RoomId);
                    if (room != null)
                    {
                        room.Status = false; // Đánh dấu là đã có người ở
                        await _context.SaveChangesAsync();
                    }
                }

                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ViewBag.Error = "Có lỗi xảy ra: " + ex.Message;
                ViewBag.Rooms = new SelectList(_context.Rooms.ToList(), "Id", "RoomName", user.RoomId);
                return View(user);
            }
        }
    }
}