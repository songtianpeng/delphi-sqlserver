unit prescriptionAudit;

interface

uses
  His6Proc, YcProc, System.DateUtils, Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.Dialogs, Base, DBGridEhGrouping, ToolCtrlsEh, DBGridEhToolCtrls,
  DynVarsEh, Data.DB, DBAccess, Uni, MemDS, GridsEh, DBAxisGridsEh, DBGridEh,
  YcDBGrid, RzButton, YcButton, RzRadChk, Vcl.ExtCtrls, RzPanel, YcPanel,
  UniProvider, SQLServerUniProvider, RzRadGrp, YcGroup, Vcl.StdCtrls, Vcl.Mask,
  DBCtrlsEh, YcEdit, YcDTPicker, RzLabel, YcLabel;

type
  TfrmBase5 = class(TfrmBase)
    YcPanel1: TYcPanel;
    YcPanel2: TYcPanel;
    YcPanel3: TYcPanel;
    pnListBtn: TYcPanel;
    btnRefresh: TYcBitBtn;
    btnAudit: TYcBitBtn;
    btnAuditCancel: TYcBitBtn;
    dgRecipe: TYcDBGrid;
    qMain: TUniQuery;
    dsQMain: TUniDataSource;
    qRecipeDetail: TUniQuery;
    qAudit: TUniQuery;
    qAuditCopy: TUniQuery;
    rgStatus: TYcRadioGroup;
    lbstart: TYcLabel;
    dtpCreate_timeFrom: TYcDateTimePicker;
    lbend1: TYcLabel;
    dtpCreate_timeto: TYcDateTimePicker;
    gbAudit_time: TYcGroupBox;
    lbstart2: TYcLabel;
    lbend2: TYcLabel;
    dtpAudit_timeFrom: TYcDateTimePicker;
    dtpAudit_timeTo: TYcDateTimePicker;
    gbCreate_time: TYcGroupBox;
    procedure FormCreate(Sender: TObject);
    procedure rgStatusClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnAuditClick(Sender: TObject);
    procedure btnAuditCancelClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmBase5: TfrmBase5;

implementation

{$R *.dfm}


//点击撤销审核按钮

procedure TfrmBase5.btnAuditCancelClick(Sender: TObject);
var
  RecipeID: string;
begin
  // 检查数据集是否为空
  if qMain.IsEmpty then
  begin
    ShowMessage('无处方可取消审核！');
    Exit;
  end;

  // 检查当前记录是否未审核
  if qMain.FieldByName('audit_flag').AsInteger = 0 then
  begin
    ShowMessage('当前处方尚未审核！');
    Exit;
  end;

  // 获取选中的处方的 recipe_id
  RecipeID := qMain.FieldByName('id').AsString;

  // 查找原审核记录
  with qAudit do
  begin
    Close;
    SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE recipe_id = :recipe_id';
    ParamByName('recipe_id').AsString := RecipeID;
    Open;
    if IsEmpty then
    begin
      ShowMessage('未找到审核数据！');
      Exit;
    end;

    // 将所有记录的 invalid 字段改为 1
    while not Eof do
    begin
      Edit;
      FieldByName('invalid').AsInteger := 1;
      Post;         //提交到内存
      Next;
    end;
//    ApplyUpdates;    //提交到数据库
    try
      His6Proc.Commit([qAudit]);  // 提交到数据库
//      YcProc.MBox('设置无效成功！');
    except
      on E: Exception do
      begin
        YcProc.Cancel([qAudit]);
//        YcProc.MBox('设置无效失败！ 原因：' + e.ClassName + e.message);
      end;
    end;

    // 复制数据到 qAuditCopy，并修改字段值
    with qAuditCopy do
    begin
      Close;
      SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE recipe_id = :recipe_id';
      ParamByName('recipe_id').AsString := RecipeID;
      Open;
      while not Eof do
      begin
        Append;
        FieldByName('id').AsString := GetKey; // 自定义生成主键的方法
        FieldByName('recipe_id').AsString := RecipeID; //设置处方id
        FieldByName('recipe_detail_id').AsString := qAuditCopy.FieldByName('recipe_detail_id').AsString;
        FieldByName('flag').AsInteger := -1;
        FieldByName('invalid').AsInteger := 1;
        FieldByName('create_dept_id').AsString := User.DeptId;
        FieldByName('create_user_id').AsString := User.UserId;
        FieldByName('create_time').AsDateTime := Now;
        Post;                 //提交到内存
        Next;
      end;
//      ApplyUpdates;           //提交到数据库
      try
        His6Proc.Commit([qAuditCopy]);  // 提交到数据库
        YcProc.MBox('取消审核成功！');
      except
        on E: Exception do
        begin
          YcProc.Cancel([qAuditCopy]);
          YcProc.MBox('取消审核失败！ 原因：' + e.ClassName + e.message);
        end;
      end;
    end;
    btnRefreshClick(Sender); // 取消审核成功后刷新数据
  end;
end;

 //点击审核按钮
procedure TfrmBase5.btnAuditClick(Sender: TObject);
var
  RecipeID, RecipeDetailID: string;
begin
  inherited;
  // 检查数据集是否为空
  if qMain.IsEmpty then
  begin
    ycproc.MBox('无处方可审核！');
    Exit;
  end;

  // 检查当前记录是否已审核
  if qMain.FieldByName('audit_flag').AsInteger <> 0 then
  begin
    ycproc.MBox('当前处方已审核！');
    Exit;
  end;
  //执行到这里说明处方待审核
  // 查找处方明细数据
  with qRecipeDetail do
  begin
    Close;
    SQL.Text := 'SELECT id AS recipe_detail_id, recipe_id FROM biz_recipe_detail WHERE recipe_id = :recipe_id';
    RecipeID := qMain.FieldByName('id').AsString;
    ParamByName('recipe_id').AsString := RecipeID;
    Open;
    if IsEmpty then
    begin
      ycproc.MBox('无处方明细数据！');
      Exit;
    end;
  end;
  //有处方明细数据
  // 插入审核记录到 biz_recipe_audit 表
  with qAudit do
  begin
    Close;
    SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE 1=0'; // 使用空查询打开一个空的数据集,相当于直接添加记录
    Open;
    while not qRecipeDetail.Eof do  // 不是处方明细的最后一条数据
    begin
      Append; // 准备插入新记录
      FieldByName('id').AsString := GetKey; // 自定义生成主键的方法
      FieldByName('recipe_id').AsString := RecipeID;       //设置处方id
      FieldByName('recipe_detail_id').AsString := qRecipeDetail.FieldByName('recipe_detail_id').AsString;
      FieldByName('flag').AsInteger := 1;
      FieldByName('invalid').AsInteger := 0;
      FieldByName('data_type').AsInteger := 0;
      FieldByName('create_dept_id').AsString := User.DeptId;
      FieldByName('create_user_id').AsString := User.UserId;
      FieldByName('create_time').AsDateTime := Now;
      Post;  // 提交到内存
      qRecipeDetail.Next;  // 移动游标到下一条记录
    end;
//    ApplyUpdates; // 提交到数据库
    try
      His6Proc.Commit([qAudit]);  // 提交到数据库
      YcProc.MBox('审核成功！');
    except
      on E: Exception do
      begin
        YcProc.Cancel([qAudit]);
        YcProc.MBox('审核失败！ 原因：' + e.ClassName + e.message);
      end;
    end;
  end;
  btnRefreshClick(Sender); // 审核成功后刷新数据,相当于点击刷新按钮
end;

//点击刷新按钮
procedure TfrmBase5.btnRefreshClick(Sender: TObject);
var
  SQL: string;
begin
  inherited;
  //初始SQL
  SQL := 'SELECT CASE WHEN ISNULL(ra.id, ''$'') <> ''$'' THEN 1 ELSE 0 END AS audit_flag, ' + 'r.id, r.recipe_no, r.name, r.sex, r.age, dbo.func_get_dept_name(r.bill_dept_id), ' + 'dbo.func_get_user_name(r.bill_user_id), r.bill_time, rd.order_no, rd.item_name, ' + 'rd.spec, rd.dose_num, rd.quantity, rd.unit, rd.ampoule, rd.dosage_unit, ' + 'rd.da_way, rd.da_frequency ' + 'FROM biz_recipe r ' + 'JOIN biz_recipe_detail rd ON r.id = rd.recipe_id ' + 'LEFT JOIN biz_recipe_audit ra ON rd.id = ra.recipe_detail_id AND ISNULL(ra.invalid, 0)= 0 ' + 'WHERE r.status = 1 AND r.data_type IN (0, 1) AND r.op_flag <> 2 ' + 'AND r.store_dept_id = :p_dept_id AND r.create_time BETWEEN :CreateTimeFrom AND :CreateTimeTo ';
  //在选择【全部】/【已审核】时
  if rgStatus.ItemIndex <> 0 then
  begin
    if ((StrToDateTime(dtpCreate_timeto.Text) - StrToDateTime(dtpCreate_timeFrom.Text) < 31) and (StrToDateTime(dtpCreate_timeto.Text) > StrToDateTime(dtpCreate_timeFrom.Text))) then
    begin
        //进行【全部】/【已审核】SQL的编写
      if rgStatus.ItemIndex = 1 then      //【已审核】就拼接SQL条件,【全部】就不拼接条件
      begin
        qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
      end;
    end
    else
    begin
      YcProc.MBox_Warning('截止时间与起止时间间隔不能大于31天且截止时间大于起止时间！');
      Exit;
    end;
    //判断四个时间输入框都不为空时,创建时间不会为空，无需判断
    if ((dtpAudit_timeFrom.Text <> '') and (dtpAudit_timeTo.Text <> '')) then
    begin
      //继续判断如果截止时间>=起始时间，且间隔天数不超31天时
      if ((StrToDateTime(dtpAudit_timeTo.Text) - StrToDateTime(dtpAudit_timeFrom.Text) < 31) and (StrToDateTime(dtpAudit_timeTo.Text) > StrToDateTime(dtpAudit_timeFrom.Text))) then
      begin
        SQL := SQL + 'AND ra.create_time BETWEEN :AuditTimeFrom AND :AuditTimeTo';
        qMain.SQL.Text := SQL;
        qMain.ParamByName('p_dept_id').AsString := His6Proc.User.DeptId;
        qMain.ParamByName('CreateTimeFrom').AsDateTime := dtpCreate_timeFrom.DateTime;
        qMain.ParamByName('CreateTimeTo').AsDateTime := dtpCreate_timeto.DateTime;
        qMain.ParamByName('AuditTimeFrom').AsDateTime := dtpAudit_timeFrom.DateTime;
        qMain.ParamByName('AuditTimeTo').AsDateTime := dtpAudit_timeTo.DateTime;
        //进行【全部】/【已审核】刷新操作
        if rgStatus.ItemIndex = 1 then      //【已审核】就拼接SQL,全部就不拼接条件
        begin
          qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
        end;
      end
      else
      begin
        YcProc.MBox_Warning('截止时间与起止时间间隔不能大于31天且截止时间大于起止时间！');
        Exit;
      end;
    end
    else if ((dtpAudit_timeFrom.Text = '') and (dtpAudit_timeTo.Text = '')) then  //输入同时为空,审核时间允许为空，就按照其创建时间查询
    begin
      qMain.SQL.Text := SQL;
      qMain.ParamByName('p_dept_id').AsString := His6Proc.User.DeptId;
      qMain.ParamByName('CreateTimeFrom').AsDateTime := dtpCreate_timeFrom.DateTime;
      qMain.ParamByName('CreateTimeTo').AsDateTime := dtpCreate_timeto.DateTime;
      if rgStatus.ItemIndex = 1 then      //【已审核】就拼接SQL,全部就不拼接条件
      begin
        qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
      end;
    end
    else     //时间输入有一个空
    begin
      YcProc.MBox_Warning('起始时间和截止时间不能有一个为空！');
      Exit;
    end;
  end;
  // 在选择【待审核】时
  if rgStatus.ItemIndex = 0 then
  begin
    //创建时间不会为空，直接判断时间间隔
    if ((StrToDateTime(dtpCreate_timeto.Text) - StrToDateTime(dtpCreate_timeFrom.Text) < 31) and (StrToDateTime(dtpCreate_timeto.Text) > StrToDateTime(dtpCreate_timeFrom.Text))) then
    begin
      qMain.SQL.Text := SQL;
      qMain.ParamByName('p_dept_id').AsString := His6Proc.User.DeptId;
      qMain.ParamByName('CreateTimeFrom').AsDateTime := dtpCreate_timeFrom.DateTime;
      qMain.ParamByName('CreateTimeTo').AsDateTime := dtpCreate_timeto.DateTime;
      qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is null ';
    end
    else
    begin
      YcProc.MBox_Warning('时间间隔不能大于31天且截止时间大于起止时间！');
      Exit;
    end;
  end;

  qMain.SQL.Text := qMain.SQL.Text + 'ORDER BY r.create_time DESC, r.recipe_no, rd.order_no';
  qMain.Open;         //打开结果集刷新
end;

//窗体创建
procedure TfrmBase5.FormCreate(Sender: TObject);
var
  StartOfDay, EndOfDay: TDateTime;
begin
  inherited;
  // 默认在【待审核】选项上
  rgStatus.ItemIndex := 0;
  // 获取当天的日期时间
  StartOfDay := StartOfTheDay(Now);
  EndOfDay := EndOfTheDay(Now);
  // 设置创建时间默认为为当天的 0 点
  dtpCreate_timeFrom.DateTime := StartOfDay;
  // 设置创建时间默认为为当天的 23:59:59
  dtpCreate_timeto.DateTime := EndOfDay;
  // 默认点击一次切换状态条件（选项）事件绑定
  rgStatusclick(Sender);
end;
 // 设置按钮的快捷键

procedure TfrmBase5.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = []) then // 检查是否没有按下 Shift, Ctrl, Alt 键
  begin
    case Key of
      Ord('R'):
        begin
          btnRefresh.Click; // 触发 刷新 的点击事件
          Key := 0; // 阻止进一步的处理
        end;
      Ord('A'):
        begin
          btnAudit.Click; // 触发 审核 的点击事件
          Key := 0; // 阻止进一步的处理
        end;
      Ord('C'):
        begin
          btnAuditCancel.Click; // 触发 撤销审核 的点击事件
          Key := 0; // 阻止进一步的处理
        end;
    end;
  end;
end;

//审核状态选择
procedure TfrmBase5.rgStatusClick(Sender: TObject);
begin
  inherited;
  //在选择【全部】/【已审核】时改变审核起止时间两个框的enabled=true，其他=false
  if rgStatus.ItemIndex <> 0 then
  begin
    dtpAudit_timeFrom.Enabled := True;
    dtpAudit_timeTo.Enabled := True;
  end
  else
  begin
    dtpAudit_timeFrom.Enabled := False;
    dtpAudit_timeTo.Enabled := False;
  end;
    // 等效再点击刷新按钮
  btnRefreshClick(Sender);
end;

end.

