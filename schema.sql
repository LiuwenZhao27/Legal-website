-- ============================================================
-- 公司法务事项管理平台 - Supabase 建表脚本
-- ============================================================
-- 执行方法（按优先级排列）:
--   1. Supabase Dashboard > SQL Editor（推荐，直接在浏览器执行）
--   2. Management API（通过 Python http.client + ensure_ascii=False）
-- 
-- ⚠️ 编码警告:
--   - 脚本含中文字符（UTF-8），禁止通过 PowerShell Invoke-RestMethod 发送
--   - 禁止通过 psycopg2 等直接连接执行（IPv6-only 主机，中文会损坏）
--   - 中文损坏后数据会变成 ??? (0x3f)，导致 CHECK 约束失效
--   - 诊断: SELECT encode(col::bytea, 'hex') FROM table;
-- ============================================================

-- 1. 创建主表
CREATE TABLE IF NOT EXISTS legal_projects (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_name    TEXT NOT NULL,
  project_type    TEXT NOT NULL DEFAULT '专项法律咨询'
                  CHECK (project_type IN ('常务法律项目', '专项法律咨询', '诉讼专项')),
  category_tag    TEXT DEFAULT '',
  project_status  TEXT NOT NULL DEFAULT '筹备中'
                  CHECK (project_status IN ('筹备中', '已决策', '诉讼中', '执行中', '已结束')),
  litigation_phase TEXT DEFAULT ''
                  CHECK (litigation_phase IN ('', '一审起诉', '一审审理', '二审上诉', '二审审理', '再审', '执行阶段', '已结案')),
  start_date      DATE NOT NULL,
  end_date        DATE,
  person_in_charge TEXT DEFAULT '',
  fee             NUMERIC(12,2) DEFAULT 0,
  fee_payment_status TEXT DEFAULT '未支付'
                  CHECK (fee_payment_status IN ('未支付', '已支付', '已确认')),
  fee_payment_date DATE,
  notes           TEXT DEFAULT '',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 索引
CREATE INDEX IF NOT EXISTS idx_projects_type      ON legal_projects(project_type);
CREATE INDEX IF NOT EXISTS idx_projects_status    ON legal_projects(project_status);
CREATE INDEX IF NOT EXISTS idx_projects_start     ON legal_projects(start_date);
CREATE INDEX IF NOT EXISTS idx_projects_category  ON legal_projects(category_tag);
CREATE INDEX IF NOT EXISTS idx_projects_person    ON legal_projects(person_in_charge);
CREATE INDEX IF NOT EXISTS idx_projects_fee_status ON legal_projects(fee_payment_status);

-- 3. 自动更新 updated_at 触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_legal_projects_updated_at ON legal_projects;
CREATE TRIGGER trg_legal_projects_updated_at
  BEFORE UPDATE ON legal_projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 4. 行级安全策略（RLS）
ALTER TABLE legal_projects ENABLE ROW LEVEL SECURITY;

-- 允许 anon 角色进行所有操作（公开访问）
-- 如需更严格的控制，请在 Supabase Dashboard > Authentication > Policies 中调整
CREATE POLICY "Enable all for anon"
  ON legal_projects
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- 5. 插入示例数据（可选，方便测试）
INSERT INTO legal_projects (project_name, project_type, category_tag, project_status, litigation_phase, start_date, end_date, person_in_charge, fee, fee_payment_status, notes) VALUES
('2026年度合同审查',          '常务法律项目', '合同管理',   '执行中', '',  '2026-01-15', '2026-12-31', '柳文',  5000,  '已支付', '年度常规合同审查工作'),
('劳动合规专项检查',          '常务法律项目', '合规审查',   '已结束', '',  '2026-02-01', '2026-04-30', '林晓',  8000,  '已支付', '公司劳动用工合规全面排查'),
('园区租赁合同谈判',          '专项法律咨询', '租赁事务',   '执行中', '',  '2026-03-01', '2026-06-30', '柳文',  12000, '已确认', '与兴远实业的园区场地收储合同纠纷相关'),
('知识产权保护咨询',          '专项法律咨询', '知识产权',   '已决策', '',  '2026-05-01', '2026-08-31', '张明',  15000, '未支付', '商标及专利保护策略咨询'),
('开博人才股权转让纠纷',      '诉讼专项',   '股权纠纷',   '诉讼中', '一审起诉', '2026-01-10', '2026-09-30', '柳文',  50000, '已支付', '开博人才股权0元误转开弈人力撤销诉讼，标的300万'),
('兴远实业合同纠纷',          '诉讼专项',   '合同纠纷',   '诉讼中', '一审审理', '2025-11-01', '2026-07-31', '柳文',  35000, '已确认', '园区场地收储合同纠纷，涉普陀区与金山区物业'),
('同缘保安劳务争议',          '诉讼专项',   '劳动争议',   '筹备中', '',        '2026-06-01', NULL,        '陈刚',  8000,  '未支付', '同缘保安公司安保服务纠纷');
