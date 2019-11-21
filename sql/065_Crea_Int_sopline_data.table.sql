IF not EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dbo.INT_SOPLINE_DATA') AND OBJECTPROPERTY(id,N'IsTable') = 1)
begin

CREATE TABLE [dbo].[INT_SOPLINE_DATA](
	[SOPTYPE] [smallint] NOT NULL,
	[SOPNUMBE] [char](21) NOT NULL,
	[LNITMSEQ] [int] NOT NULL,
	[ARTIC_NAME] [char](101) NOT NULL,
	[APPPRCLST] [char](5) NOT NULL,
	[ARTIC_DESC] [char](255) NOT NULL,
	[BUY_NOTE] [char](255) NOT NULL,
	[COLL_NAME] [char](51) NOT NULL,
	[ARTIC_INFO] [char](255) NOT NULL,
	[USAGE_DESC] [char](255) NOT NULL,
	[USAGE_RIGHTS] [char](255) NOT NULL,
	[MPUBDATE] [datetime] NOT NULL,
	[PUBEXPDATE] [datetime] NOT NULL,
	[MPUBCCODE] [char](3) NOT NULL,
	[DDTONINV] [datetime] NOT NULL,
	[DEX_ROW_ID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PKINT_SOPLINE_DATA] PRIMARY KEY NONCLUSTERED 
(
	[SOPTYPE] ASC,
	[SOPNUMBE] ASC,
	[LNITMSEQ] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

end
