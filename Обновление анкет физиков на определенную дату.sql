declare @RetVal int
declare @ContractID DSIDENTIFIER
declare @InstrumentID DSIDENTIFIER,

  
 @InstMainChangeID DSIDENTIFIER,
 @InstitutionID DSIDENTIFIER,
 @Date DSOPERDAY,
 @Comment varchar(255)



   DECLARE R_cursor  CURSOR

    FOR select  i.InstitutionID
	   from tInstitution i (NOLOCK)
	   where 1=1
	     and i.PropDealpart = 0
 

    OPEN  R_cursor
    fetch R_cursor into  @InstitutionID   


    while @@fetch_status = 0

    begin

      

                         exec @RetVal = InstMainChange_Insert              
                     @InstMainChangeID = @InstMainChangeID output,               
                     @InstitutionID    = @InstitutionID,               
                     @Date             = '20160628',               
                     @Comment          = '≈жегодное обновление сведений о  лиентах'

select @RetVal

       if @RetVal != 0

        select RetCode, Message from tReturnCode where RetCode = @RetVal

     

    fetch R_cursor into  @InstitutionID   

      
    end

          
    deallocate R_cursor

	/* проверка сколько клиентов в этот день обновили анкеты
	select distinct im.InstitutionID from tInstMainChange im, 
 tInstitution i (NOLOCK)
	   where 
	   1=1
	   and i.InstitutionID = im.InstitutionID
	     and i.PropDealpart = 0
		 and im.Date = '20160628'
		 */