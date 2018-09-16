/****** Object:  UserDefinedFunction [dbo].[encode_bc128]    Script Date: 9/15/2018 8:44:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--------------------[procedure encode_bc128]--------------------
  --
  -- Function to transform a character string into a chain of
  -- codes 128 in T-SQL.
  -- (Translation of the function VB de Grandzebu by Nicolas
  --  Fanchamps in T-SQL)
  --
 CREATE function [dbo].[ENCODE_BC128] (
    @InputString                nvarchar(max))
    returns                     nvarchar(max)
BEGIN

    DECLARE @idx                        int = 1;      -- Index in the character string
    DECLARE @ascii_temp                 int;           -- Temporary ascii code variable
    DECLARE @checksum                   int;           -- Checksum character of the coded chain
    DECLARE @mini                       int;           -- number of digital characters following
    DECLARE @dummy                      int;           -- Buffer for 2 (or more) adjacent numeric characters
    DECLARE @tableB                     bit;       -- Boolean to use table B of code 128
    DECLARE @code128                    nvarchar(100);-- Coded string
    DECLARE @StrLength                  int;           -- Length of the resilting chain

    -- Initialize variables
    set @code128  = '';
    set @StrLength = LEN(@InputString);

    --##############################################
    --#                                            #
    --# First part: checking of the chain and      #
    --# application errors as appropriate          #
    --#                                            #
    --##############################################

    if (ltrim(rtrim(@InputString)) is null)
     --tsql function can't raise error  a hack can be  return cast('Code 128 conversion error: Empty Input String!' as int);
		return null;

     --If the input is has a non-ascii character then error 15600
      while @idx <= @StrLength
        begin
			  set @ascii_temp = ASCII(SUBSTRING(@InputString, @idx, 1));
			  if (@ascii_temp < 32) or (@ascii_temp > 126) 
			 --tsql function can't raise error  a hack can be   'Code 128 conversion error: Invalid Input String!')
					return null;
			  set @idx = @idx +1;
		end;
		set @idx = 1;

    --##############################################
    --#                                            #
    --# Second part: encoding of the chain by      #
    --# optimizing the use of the table B and C    #
    --#                                            #
    --##############################################

    set @tableB = 1;
    while @idx <= @StrLength begin
      -- Main loop

      if (@tableB = 1)
        begin
					  -- Test to see whether it is necessary to pass to table C
					  -- Yes for 4 digits at the beginning or the end, if not for 6 digits
					  if ((@idx = 1) or (@idx + 3 = @StrLength))
						set @mini = 4;
					  else
						set @mini = 6;
        

				  --TestNum: if mini digital characters starting from idx its, then mini = 0
				  set @mini = @mini - 1;
				  if ((@idx + @mini) <= @StrLength)
					begin
					  while @mini >= 0 begin
						set @ascii_temp = ASCII(substring(@InputString, @idx + @mini, 1));
						if (@ascii_temp < 48) or (@ascii_temp > 57)
						  break;
						set @mini = @mini - 1;
					  end;
					end;

				  -- If mini < 0 one pass in table C
				  if (@mini < 0)
					begin
					  if (@idx = 1)
						begin
						  -- Begin on the table C
						  set @code128 = char(210);
						end;
					  else
						begin
						  -- Commutate on the table C
						  set @code128 = @code128 + char(204); 
						end;
					  set @tableB = 0;
					end;
				  else begin
					if (@idx = 1)
					  begin
						-- Begin on the table B
						set @code128 = char(209); 
					  end;
				  end;
	  end;
----------------------------------------------------------------------------------------------------------------------------------
      if (@tableB = 0)
        begin
					  -- One is on the table C, one will try to treat 2 digits
					  set @mini = 2;
					  set @mini = @mini - 1;
					  if (@idx + @mini <= @StrLength)
						begin
						  while @mini >= 0 begin
							set @ascii_temp = ASCII(substring(@InputString, @idx + @mini, 1));
							if (@ascii_temp < 48) OR (@ascii_temp > 57)
							  begin
								break; 
							  end;
							set @mini = @mini - 1;
						  end;
						end;

					  if (@mini < 0)
						begin
						  -- OK For 2 digits, to treat them
						  set @dummy = cast(substring(@InputString, @idx, 2) as integer);
						  if (@dummy < 95)
							  set @dummy = @dummy + 32;
						  else
							set @dummy = @dummy + 105;
						set @code128 = @code128 + nchar(@dummy);
						set @idx = @idx + 2;
						end;
					  else begin
						-- One does not have two digits, to turn over in table B
						set @code128 = @code128 + nchar(205); --    unistr('\00CD');
						set @tableB = 1;
					end;
		end;
----------------------------------------------------------------------------------------------------------------------------------

      if (@tableB = 1)
        begin
          set @code128 = @code128 + substring(@InputString, @idx, 1);
          set @idx = @idx + 1;
        end;
	

    end; -- Main loop end

    -- Calculation of the checksum
     set @idx = 1;
      while @idx <= len(@code128) begin
     set @dummy = ASCII(substring(@code128, @idx, 1));
     if (@dummy < 127)
      set @dummy = @dummy - 32;
     else
     set @dummy = @dummy - 105;

     if (@idx = 1)
      set @checksum = @dummy;

    set @checksum = (@checksum + ((@idx - 1) * @dummy)) % 103;
	set @idx = @idx+1;
    end;

    -- Calculation of the ASCII code of the control key
    if (@checksum < 95)
    set @checksum = @checksum + 32;
    else
     set @checksum = @checksum + 105;


    -- Addition of the chksum character and the STOP character at the end of the coded chain
    set @code128 = @code128 + nchar(@checksum) + nchar(211);     
    return(@code128);

   end;