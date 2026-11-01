using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Linq;
using quanlyphongtro.DATA;
using Microsoft.EntityFrameworkCore;

namespace quanlyphongtro.Controllers
{
    public class AccountController : Controller
    {
        private readonly ApplicationDbContext _context;

        public AccountController(ApplicationDbContext context)
        {
            _context = context;
        }

        // Hiển thị trang đăng nhập
        public IActionResult Login() => View();

        [HttpPost]
        public IActionResult Login(string username, string password)
        {
            // 1. Tìm user - Kiểm tra khớp Username và Password
            // Sử dụng AsNoTracking để tăng tốc độ vì ta chỉ cần đọc dữ liệu
            var user = _context.Users
                .AsNoTracking()
                .FirstOrDefault(u => u.Username == username && u.Password == password);

            if (user != null)
            {
                // 2. Xử lý Role an toàn (Tránh lỗi nếu cột Role trong DB bị null)
                // .Trim() để xóa khoảng trắng thừa, .ToLower() để dễ so sánh
                string userRole = (user.Role ?? "user").ToLower().Trim();

                // 3. Lưu thông tin vào Session
                HttpContext.Session.SetString("User", user.Username);
                HttpContext.Session.SetString("Role", userRole);

                // 4. Phân quyền chuyển hướng bằng switch-case (Rõ ràng và dễ mở rộng)
                switch (userRole)
                {
                    case "owner":
                    case "manager":
                        // Nếu là Chủ nhà hoặc Quản lý -> Đi tới trang Quản lý phòng
                        return RedirectToAction("Index", "Rooms");

                    case "user":
                    case "tenant":
                        // Nếu là Người thuê -> Đi tới trang xem Hóa đơn
                        return RedirectToAction("Index", "Invoices");

                    default:
                        // Các trường hợp khác về trang chủ
                        return RedirectToAction("Index", "Home");
                }
            }

            // 5. Nếu sai tài khoản hoặc mật khẩu, thông báo lỗi ra View
            ViewBag.Error = "Tài khoản hoặc mật khẩu không chính xác!";
            return View();
        }

        // Đăng xuất: Xóa sạch Session và về trang Login
        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return RedirectToAction("Login");
        }
    }
}