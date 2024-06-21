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


//���������˰�ť

procedure TfrmBase5.btnAuditCancelClick(Sender: TObject);
var
  RecipeID: string;
begin
  // ������ݼ��Ƿ�Ϊ��
  if qMain.IsEmpty then
  begin
    ShowMessage('�޴�����ȡ����ˣ�');
    Exit;
  end;

  // ��鵱ǰ��¼�Ƿ�δ���
  if qMain.FieldByName('audit_flag').AsInteger = 0 then
  begin
    ShowMessage('��ǰ������δ��ˣ�');
    Exit;
  end;

  // ��ȡѡ�еĴ����� recipe_id
  RecipeID := qMain.FieldByName('id').AsString;

  // ����ԭ��˼�¼
  with qAudit do
  begin
    Close;
    SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE recipe_id = :recipe_id';
    ParamByName('recipe_id').AsString := RecipeID;
    Open;
    if IsEmpty then
    begin
      ShowMessage('δ�ҵ�������ݣ�');
      Exit;
    end;

    // �����м�¼�� invalid �ֶθ�Ϊ 1
    while not Eof do
    begin
      Edit;
      FieldByName('invalid').AsInteger := 1;
      Post;         //�ύ���ڴ�
      Next;
    end;
//    ApplyUpdates;    //�ύ�����ݿ�
    try
      His6Proc.Commit([qAudit]);  // �ύ�����ݿ�
//      YcProc.MBox('������Ч�ɹ���');
    except
      on E: Exception do
      begin
        YcProc.Cancel([qAudit]);
//        YcProc.MBox('������Чʧ�ܣ� ԭ��' + e.ClassName + e.message);
      end;
    end;

    // �������ݵ� qAuditCopy�����޸��ֶ�ֵ
    with qAuditCopy do
    begin
      Close;
      SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE recipe_id = :recipe_id';
      ParamByName('recipe_id').AsString := RecipeID;
      Open;
      while not Eof do
      begin
        Append;
        FieldByName('id').AsString := GetKey; // �Զ������������ķ���
        FieldByName('recipe_id').AsString := RecipeID; //���ô���id
        FieldByName('recipe_detail_id').AsString := qAuditCopy.FieldByName('recipe_detail_id').AsString;
        FieldByName('flag').AsInteger := -1;
        FieldByName('invalid').AsInteger := 1;
        FieldByName('create_dept_id').AsString := User.DeptId;
        FieldByName('create_user_id').AsString := User.UserId;
        FieldByName('create_time').AsDateTime := Now;
        Post;                 //�ύ���ڴ�
        Next;
      end;
//      ApplyUpdates;           //�ύ�����ݿ�
      try
        His6Proc.Commit([qAuditCopy]);  // �ύ�����ݿ�
        YcProc.MBox('ȡ����˳ɹ���');
      except
        on E: Exception do
        begin
          YcProc.Cancel([qAuditCopy]);
          YcProc.MBox('ȡ�����ʧ�ܣ� ԭ��' + e.ClassName + e.message);
        end;
      end;
    end;
    btnRefreshClick(Sender); // ȡ����˳ɹ���ˢ������
  end;
end;

 //�����˰�ť
procedure TfrmBase5.btnAuditClick(Sender: TObject);
var
  RecipeID, RecipeDetailID: string;
begin
  inherited;
  // ������ݼ��Ƿ�Ϊ��
  if qMain.IsEmpty then
  begin
    ycproc.MBox('�޴�������ˣ�');
    Exit;
  end;

  // ��鵱ǰ��¼�Ƿ������
  if qMain.FieldByName('audit_flag').AsInteger <> 0 then
  begin
    ycproc.MBox('��ǰ��������ˣ�');
    Exit;
  end;
  //ִ�е�����˵�����������
  // ���Ҵ�����ϸ����
  with qRecipeDetail do
  begin
    Close;
    SQL.Text := 'SELECT id AS recipe_detail_id, recipe_id FROM biz_recipe_detail WHERE recipe_id = :recipe_id';
    RecipeID := qMain.FieldByName('id').AsString;
    ParamByName('recipe_id').AsString := RecipeID;
    Open;
    if IsEmpty then
    begin
      ycproc.MBox('�޴�����ϸ���ݣ�');
      Exit;
    end;
  end;
  //�д�����ϸ����
  // ������˼�¼�� biz_recipe_audit ��
  with qAudit do
  begin
    Close;
    SQL.Text := 'SELECT * FROM biz_recipe_audit WHERE 1=0'; // ʹ�ÿղ�ѯ��һ���յ����ݼ�,�൱��ֱ����Ӽ�¼
    Open;
    while not qRecipeDetail.Eof do  // ���Ǵ�����ϸ�����һ������
    begin
      Append; // ׼�������¼�¼
      FieldByName('id').AsString := GetKey; // �Զ������������ķ���
      FieldByName('recipe_id').AsString := RecipeID;       //���ô���id
      FieldByName('recipe_detail_id').AsString := qRecipeDetail.FieldByName('recipe_detail_id').AsString;
      FieldByName('flag').AsInteger := 1;
      FieldByName('invalid').AsInteger := 0;
      FieldByName('data_type').AsInteger := 0;
      FieldByName('create_dept_id').AsString := User.DeptId;
      FieldByName('create_user_id').AsString := User.UserId;
      FieldByName('create_time').AsDateTime := Now;
      Post;  // �ύ���ڴ�
      qRecipeDetail.Next;  // �ƶ��α굽��һ����¼
    end;
//    ApplyUpdates; // �ύ�����ݿ�
    try
      His6Proc.Commit([qAudit]);  // �ύ�����ݿ�
      YcProc.MBox('��˳ɹ���');
    except
      on E: Exception do
      begin
        YcProc.Cancel([qAudit]);
        YcProc.MBox('���ʧ�ܣ� ԭ��' + e.ClassName + e.message);
      end;
    end;
  end;
  btnRefreshClick(Sender); // ��˳ɹ���ˢ������,�൱�ڵ��ˢ�°�ť
end;

//���ˢ�°�ť
procedure TfrmBase5.btnRefreshClick(Sender: TObject);
var
  SQL: string;
begin
  inherited;
  //��ʼSQL
  SQL := 'SELECT CASE WHEN ISNULL(ra.id, ''$'') <> ''$'' THEN 1 ELSE 0 END AS audit_flag, ' + 'r.id, r.recipe_no, r.name, r.sex, r.age, dbo.func_get_dept_name(r.bill_dept_id), ' + 'dbo.func_get_user_name(r.bill_user_id), r.bill_time, rd.order_no, rd.item_name, ' + 'rd.spec, rd.dose_num, rd.quantity, rd.unit, rd.ampoule, rd.dosage_unit, ' + 'rd.da_way, rd.da_frequency ' + 'FROM biz_recipe r ' + 'JOIN biz_recipe_detail rd ON r.id = rd.recipe_id ' + 'LEFT JOIN biz_recipe_audit ra ON rd.id = ra.recipe_detail_id AND ISNULL(ra.invalid, 0)= 0 ' + 'WHERE r.status = 1 AND r.data_type IN (0, 1) AND r.op_flag <> 2 ' + 'AND r.store_dept_id = :p_dept_id AND r.create_time BETWEEN :CreateTimeFrom AND :CreateTimeTo ';
  //��ѡ��ȫ����/������ˡ�ʱ
  if rgStatus.ItemIndex <> 0 then
  begin
    if ((StrToDateTime(dtpCreate_timeto.Text) - StrToDateTime(dtpCreate_timeFrom.Text) < 31) and (StrToDateTime(dtpCreate_timeto.Text) > StrToDateTime(dtpCreate_timeFrom.Text))) then
    begin
        //���С�ȫ����/������ˡ�SQL�ı�д
      if rgStatus.ItemIndex = 1 then      //������ˡ���ƴ��SQL����,��ȫ�����Ͳ�ƴ������
      begin
        qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
      end;
    end
    else
    begin
      YcProc.MBox_Warning('��ֹʱ������ֹʱ�������ܴ���31���ҽ�ֹʱ�������ֹʱ�䣡');
      Exit;
    end;
    //�ж��ĸ�ʱ������򶼲�Ϊ��ʱ,����ʱ�䲻��Ϊ�գ������ж�
    if ((dtpAudit_timeFrom.Text <> '') and (dtpAudit_timeTo.Text <> '')) then
    begin
      //�����ж������ֹʱ��>=��ʼʱ�䣬�Ҽ����������31��ʱ
      if ((StrToDateTime(dtpAudit_timeTo.Text) - StrToDateTime(dtpAudit_timeFrom.Text) < 31) and (StrToDateTime(dtpAudit_timeTo.Text) > StrToDateTime(dtpAudit_timeFrom.Text))) then
      begin
        SQL := SQL + 'AND ra.create_time BETWEEN :AuditTimeFrom AND :AuditTimeTo';
        qMain.SQL.Text := SQL;
        qMain.ParamByName('p_dept_id').AsString := His6Proc.User.DeptId;
        qMain.ParamByName('CreateTimeFrom').AsDateTime := dtpCreate_timeFrom.DateTime;
        qMain.ParamByName('CreateTimeTo').AsDateTime := dtpCreate_timeto.DateTime;
        qMain.ParamByName('AuditTimeFrom').AsDateTime := dtpAudit_timeFrom.DateTime;
        qMain.ParamByName('AuditTimeTo').AsDateTime := dtpAudit_timeTo.DateTime;
        //���С�ȫ����/������ˡ�ˢ�²���
        if rgStatus.ItemIndex = 1 then      //������ˡ���ƴ��SQL,ȫ���Ͳ�ƴ������
        begin
          qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
        end;
      end
      else
      begin
        YcProc.MBox_Warning('��ֹʱ������ֹʱ�������ܴ���31���ҽ�ֹʱ�������ֹʱ�䣡');
        Exit;
      end;
    end
    else if ((dtpAudit_timeFrom.Text = '') and (dtpAudit_timeTo.Text = '')) then  //����ͬʱΪ��,���ʱ������Ϊ�գ��Ͱ����䴴��ʱ���ѯ
    begin
      qMain.SQL.Text := SQL;
      qMain.ParamByName('p_dept_id').AsString := His6Proc.User.DeptId;
      qMain.ParamByName('CreateTimeFrom').AsDateTime := dtpCreate_timeFrom.DateTime;
      qMain.ParamByName('CreateTimeTo').AsDateTime := dtpCreate_timeto.DateTime;
      if rgStatus.ItemIndex = 1 then      //������ˡ���ƴ��SQL,ȫ���Ͳ�ƴ������
      begin
        qMain.SQL.Text := qMain.SQL.Text + 'and ra.id is not null ';
      end;
    end
    else     //ʱ��������һ����
    begin
      YcProc.MBox_Warning('��ʼʱ��ͽ�ֹʱ�䲻����һ��Ϊ�գ�');
      Exit;
    end;
  end;
  // ��ѡ�񡾴���ˡ�ʱ
  if rgStatus.ItemIndex = 0 then
  begin
    //����ʱ�䲻��Ϊ�գ�ֱ���ж�ʱ����
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
      YcProc.MBox_Warning('ʱ�������ܴ���31���ҽ�ֹʱ�������ֹʱ�䣡');
      Exit;
    end;
  end;

  qMain.SQL.Text := qMain.SQL.Text + 'ORDER BY r.create_time DESC, r.recipe_no, rd.order_no';
  qMain.Open;         //�򿪽����ˢ��
end;

//���崴��
procedure TfrmBase5.FormCreate(Sender: TObject);
var
  StartOfDay, EndOfDay: TDateTime;
begin
  inherited;
  // Ĭ���ڡ�����ˡ�ѡ����
  rgStatus.ItemIndex := 0;
  // ��ȡ���������ʱ��
  StartOfDay := StartOfTheDay(Now);
  EndOfDay := EndOfTheDay(Now);
  // ���ô���ʱ��Ĭ��ΪΪ����� 0 ��
  dtpCreate_timeFrom.DateTime := StartOfDay;
  // ���ô���ʱ��Ĭ��ΪΪ����� 23:59:59
  dtpCreate_timeto.DateTime := EndOfDay;
  // Ĭ�ϵ��һ���л�״̬������ѡ��¼���
  rgStatusclick(Sender);
end;
 // ���ð�ť�Ŀ�ݼ�

procedure TfrmBase5.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = []) then // ����Ƿ�û�а��� Shift, Ctrl, Alt ��
  begin
    case Key of
      Ord('R'):
        begin
          btnRefresh.Click; // ���� ˢ�� �ĵ���¼�
          Key := 0; // ��ֹ��һ���Ĵ���
        end;
      Ord('A'):
        begin
          btnAudit.Click; // ���� ��� �ĵ���¼�
          Key := 0; // ��ֹ��һ���Ĵ���
        end;
      Ord('C'):
        begin
          btnAuditCancel.Click; // ���� ������� �ĵ���¼�
          Key := 0; // ��ֹ��һ���Ĵ���
        end;
    end;
  end;
end;

//���״̬ѡ��
procedure TfrmBase5.rgStatusClick(Sender: TObject);
begin
  inherited;
  //��ѡ��ȫ����/������ˡ�ʱ�ı������ֹʱ���������enabled=true������=false
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
    // ��Ч�ٵ��ˢ�°�ť
  btnRefreshClick(Sender);
end;

end.

