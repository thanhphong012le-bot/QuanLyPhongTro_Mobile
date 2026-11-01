using Microsoft.AspNetCore.Mvc;
using quanlyphongtro.DATA;


namespace quanlyphongtro.Controllers
{
    public class ContractsController : Controller
    {
        private readonly ApplicationDbContext _context;

        public ContractsController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. Dành cho Chủ nhà/Quản lý: Xem danh sách yêu cầu hợp đồng
        public IActionResult Index()
        {
            var role = HttpContext.Session.GetString("Role")?.ToLower();

            if (role == "owner" || role == "manager")
            {
                var contracts = _context.Contracts
                    .OrderByDescending(c => c.CreatedDate)
                    .ToList();

                return View(contracts);
            }

            return RedirectToAction("Login", "Account");
        }

        // 2. Dành cho Người thuê: Hiển thị Form nhập thông tin
        public IActionResult Create()
        {
            var model = new quanlyphongtro.Models.Contract
            {
                StartDate = DateTime.Now,
                ContractTerm = 1 // Mặc định 1 năm
            };
            return View(model);
        }

        // Xử lý lưu thông tin hợp đồng
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(quanlyphongtro.Models.Contract contract)
        {
            // Kiểm tra tính hợp lệ của dữ liệu dựa trên Model (CCCD, PhoneNumber, FullName...)
            if (ModelState.IsValid)
            {
                // LOGIC: Tính ngày kết thúc = Ngày bắt đầu + Số năm hợp đồng
                contract.EndDate = contract.StartDate.AddYears(contract.ContractTerm);

                contract.CreatedDate = DateTime.Now;
                contract.Status = "Pending"; // Mặc định là Chờ duyệt

                _context.Contracts.Add(contract);
                _context.SaveChanges();

                TempData["Success"] = "Gửi thông tin hợp đồng thành công!";
                return RedirectToAction("Index", "Home");
            }

            // Nếu nhập thiếu (ví dụ quên nhập CCCD), trả về trang nhập để báo lỗi
            return View(contract);
        }

        // 3. Duyệt hợp đồng (Dành cho Chủ nhà)
        [HttpPost]
        public IActionResult Approve(int id)
        {
            var contract = _context.Contracts.Find(id);
            if (contract != null)
            {
                contract.Status = "Approved";
                _context.SaveChanges();
            }
            return RedirectToAction(nameof(Index));
        }

        // 4. Xóa yêu cầu hợp đồng
        [HttpPost]
        public IActionResult Delete(int id)
        {
            var contract = _context.Contracts.Find(id);
            if (contract != null)
            {
                _context.Contracts.Remove(contract);
                _context.SaveChanges();
            }
            return RedirectToAction(nameof(Index));
        }
    }
}