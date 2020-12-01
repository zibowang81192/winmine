assume cs:code,ss:stack
;背景色，两种不同的颜色以区分方格
;将下列数据送入显存区的高位

background segment
  db 5 dup(5 dup(00110000B,00110000B,00100000B,00100000B),5 dup(00100000B,00100000B,00110000B,00110000B))
background ends
;随机生成雷区，在无雷的位置设置为0
mine_filed segment
  db 200 dup(0)
mine_filed ends
;已经被探索的区域确定无雷的区域被标记为1
explored segment
  db 200 dup(0)
explored ends
;旗帜的位置
flags_filed segment
  db 200 dup(0)
flags_filed ends
;音效段
dataseg segment
mov_freq DW 262,294,-1
mov_time DW	6,6
dataseg ends

stack segment
  dw 10 dup(0)
stack ends

code segment

;直接定值表position记录光标所在的横纵坐标.
position db 0,0
num_flags db 10;旗帜的初始个数
str_flags db 'FLAGS: 10';字符占9个字节
FIRST db 1;每局游戏第一次按下j后变为0,重新开始需要设置为1
;用来存储雷的坐标，x为横坐标，y为纵坐标
x db 10 dup(?)
y db 10 dup(?)
FIRST_COORDINATE db '??';前一个字节为第一次挖开方块的横坐标，第二个为纵坐标
lose_str db 'GAME OVER'
win_str db 'YOU WIN'
NUM db 0;统计已经确定的位置的个数，当为90时获胜
;首次点击位置四周坐标
AROUND_X db 8 dup(0)
AROUND_Y db 8 dup(0)
;开始界面用到的指示文字
key_flags db 'PRESS J : ENTER THE GAME'
;游戏时间限定为5分钟
MIN db 0
SEC db 0
;变换随机数生成方式
change_flag db 0

start:
;主函数
;开始界面
CALL SCREEN

mov ax,background
mov ds,ax
mov si,0
mov ax,0b800h
mov es,ax

mov bx,1340;设置'FLAGS: '字样
mov cx,9
mov ah,00100100B
set_str_flag: mov al,str_flags[si]
mov es:[bx],ax
add bx,2
inc si
loop set_str_flag
mov si,0

mov bx,1661;对第一个方块，1661为高位存储背景，1660为低位存储字符
mov cx,10
;显示背景
;通过双循环来为10*10的区域填色
show_back1:
push cx
push bx
mov cx,20
show_back2:
mov al,[si]
mov es:[bx],al
add bx,2
inc si
loop show_back2
pop bx
pop cx
add bx,160
loop show_back1

;将第一块位置设置为初始位置
;临时选中的色块需闪烁变色
;OR 11000000B使得选中色块临时变色
;AND 00111111B恢复色块颜色
mov bx,1661
or byte ptr es:[bx],11000000B
mov bx,1663
or byte ptr es:[bx],11000000B
;主循环
MAIN_LOOP:  CALL CONTROL
CALL CHECK_PROC
JMP MAIN_LOOP

mov ax,4c00h
int 21h

MUSIC PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
PUSH SI

    mov ax, dataseg
    mov ds, ax

    lea si, mov_freq
    lea di, mov_time
	call play

play:
	mov dx, [si]
    cmp dx, -1
    je end_play
    call sound
    add si, 2
    add di, 2
    jmp play
    ret

end_play:
	mov ax, 4c00h
    int 21h

;演奏一个音符
;入口参数：si - 要演奏的音符的频率的地址
;         di - 要演奏的音符的音长的地址
sound:
    push ax
    push dx
    push cx

    ;8253 芯片(定时/计数器)的设置
    mov al,0b6h    ;8253初始化
    out 43h,al     ;43H是8253芯片控制口的端口地址
    mov dx,12h
    mov ax,34dch
    div word ptr [si] ;计算分频值,赋给ax。[si]中存放声音的频率值。
    out 42h, al       ;先送低8位到计数器，42h是8253芯片通道2的端口地址
    mov al, ah
    out 42h, al       ;后送高8位计数器

    ;设置8255芯片, 控制扬声器的开/关
    in al,61h   ;读取8255 B端口原值
    mov ah,al   ;保存原值
    or al,3     ;使低两位置1，以便打开开关
    out 61h,al  ;开扬声器, 发声
    mov dx, [di]       ;保持[di]时长
wait1:
    mov cx, 28000
delay:
    nop
    loop delay
    dec dx
    jnz wait1

    mov al, ah         ;恢复扬声器端口原值
    out 61h, al

    pop cx
    pop dx
    pop ax
    ret

POP SI
POP DS
POP DX
POP CX
POP BX
POP AX
RET

MUSIC ENDP

SCREEN PROC
push ax
push bx
push cx
push dx
push es
push ds
push si
mov cx,60
;换行
out_ct: call OUTPUT_CTLF
loop out_ct

mov ax,0b800h
mov es,ax

mov al,00110000B ;设置颜色

;方框
mov bx,665
line1:
mov es:[bx],al
add bx,2
cmp bx,773
jbe line1

mov bx,2905
line2:
mov es:[bx],al
add bx,2
cmp bx,3013
jbe line2

mov bx,825
line3:
mov es:[bx],al
add bx,2
mov es:[bx],al
sub bx,2
add bx,160
cmp bx,2905
jb line3

mov bx,931
line4:
mov es:[bx],al
add bx,2
mov es:[bx],al
sub bx,2
add bx,160
cmp bx,3011
jb line4

;字母M
mov bx,1015
call vline
mov bx,1023
call vline
mov bx,1177
mov es:[bx],al
add bx,4
mov es:[bx],al
add bx,160
sub bx,2
mov es:[bx],al

;字母I
mov bx,1029
mov es:[bx],al
add bx,4
mov es:[bx],al
add bx,640
mov es:[bx],al
sub bx,4
mov es:[bx],al
mov bx,1031
call vline

;字母N
mov bx,1039
call vline
mov bx,1047
call vline
mov bx,1201
mov es:[bx],al
add bx,162
mov es:[bx],al
add bx,162
mov es:[bx],al


;字母E
mov bx,1053
call vline
mov bx,1055
call hline
mov bx,1375
call hline
mov bx,1695
call hline

;字母S
mov bx,1953
mov es:[bx],al
add bx,2
call hline
mov bx,2113
mov es:[bx],al
mov bx,2273
mov es:[bx],al
add bx,2
call hline
add bx,158
mov es:[bx],al
mov bx,2593
mov es:[bx],al
add bx,2
call hline

;字母W
mov bx,1967
call vline
mov bx,1975
call vline
mov bx,2291
mov es:[bx],al
add bx,158
mov es:[bx],al
add bx,4
mov es:[bx],al

;字母E
mov bx,1981
call vline
mov bx,1983
call hline
mov bx,2303
call hline
mov bx,2623
call hline

;字母E
mov bx,1995
call vline
mov bx,1997
call hline
mov bx,2317
call hline
mov bx,2637
call hline

;字母P
mov bx,2009
call vline
mov bx,2011
call hline
mov bx,2331
call hline
mov bx,2177
mov es:[bx],al

;字母E
mov bx,2023
call vline
mov bx,2025
call hline
mov bx,2345
call hline
mov bx,2665
call hline

;字母R
mov bx,2037
call vline
mov bx,2039
call hline
mov bx,2359
call hline
mov bx,2205
mov es:[bx],al
mov bx,2523
mov es:[bx],al
mov bx,2683
mov es:[bx],al

;闪烁指示文字
mov bx,3414
mov si,0
mov cx,24
mov ah,00110000B
set_key_flag:
mov al,key_flags[si]
mov es:[bx],ax
add bx,2
inc si
loop set_key_flag

loop_screen:
mov ah,07h
int 21h
cmp al,106
je SCREEN_END
loop loop_screen

JMP SCREEN_END

;5个像素的竖线
vline:
push cx
mov cx,5
again1:
mov es:[bx],al
add bx,160
loop again1
pop cx
ret
;4个像素的横线
hline:
push cx
mov cx,4
again2:
mov es:[bx],al
add bx,2
loop again2
pop cx
ret
SCREEN_END:
;先清屏
cls:
mov bx,0b800h        ;显存地址 0xb800
mov es,bx
mov bx,0
mov cx,4000          ;文本模式显示25行，80字   即80*25*2 = 4000字节
s:
mov dl,0         ;将NULL字符，即ASCII 0 放入低位
mov dh,0              ;将颜色 0 即 黑色 放入高位
mov es:[bx],dx
add bx,2
loop s

pop si
pop ds
pop es
pop dx
pop cx
pop bx
pop ax
RET
SCREEN ENDP
;回车是0dh，换行是0Ah。
;下列程自序就是输出回车换行的。
OUTPUT_CTLF PROC NEAR
PUSH AX
PUSH DX
MOV AH, 02H ;输出单个字符.
MOV DL, 0DH ;0D是回车符的ASCII码.
INT 21H ;输出.
MOV AH, 02H
MOV DL, 0AH ;0A是换行符的ASCII码.
INT 21H
POP DX
POP AX
RET
OUTPUT_CTLF ENDP

;恢复颜色
RE_COLOR PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX

MOV AL,CH
MOV DL,160
MUL DL
ADD BX,AX
MOV AL,CL
MOV DH,2
MUL DH
ADD BX,AX
AND BYTE PTR ES:[BX],00111111B;恢复颜色
AND BYTE PTR ES:[BX+2],00111111B;恢复颜色

POP DX
POP CX
POP BX
POP AX
RET
RE_COLOR ENDP

;设置旗帜标记子过程
SET_FLAG PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
PUSH ES

MOV AX,explored
MOV DS,AX
MOV BL,20
MOV AL,position[0]
MUL BL
MOV BX,AX
ADD BL,position[1]
CMP BYTE PTR DS:[BX],1
JE SET_ENDS

MOV BX,1660;光标所在位置
MOV SI,0
MOV DH,160
MOV DL,2
MOV AL,CH
MUL DH
ADD BX,AX
MOV AL,CL
MUL DL
ADD BX,AX

MOV DH,20
MOV AL,position[0]
MUL DH
MOV SI,AX
MOV AL,position[1]
MUL DL
ADD SI,AX

MOV AX,flags_filed
MOV DS,AX
CMP BYTE PTR DS:[SI],1
JNE SET_F
INC num_flags[0]
MOV BYTE PTR DS:[SI],0H
MOV BYTE PTR ES:[BX],00000000B
MOV BYTE PTR ES:[BX+2],00000000B
JMP SET_ENDS

SET_F:  MOV AL,0
CMP num_flags[0],AL
JE SET_ENDS
DEC num_flags[0]
MOV BYTE PTR DS:[SI],01H
MOV BYTE PTR ES:[BX],16;F

SET_ENDS:
MOV AL,10
MOV BX,1354
CMP num_flags[0],AL
JNE SINGLE_DIGIT
MOV AL,49
MOV AH,00100100B
MOV ES:[BX],AX
MOV AL,48
MOV ES:[BX+2],AX
JMP OVER_SET_FLAGS
SINGLE_DIGIT: MOV AL,num_flags[0]
ADD AL,48
MOV AH,00100100B
MOV ES:[BX+2],AX
MOV AL,32
MOV ES:[BX],AX
OVER_SET_FLAGS:
POP ES
POP DS
POP DX
POP CX
POP BX
POP AX
RET

SET_FLAG ENDP

;检测胜利
CHECK_PROC PROC
PUSH AX
PUSH CX
PUSH DX
PUSH SI
MOV AL,0
MOV NUM[0],AL
MOV AX,explored
MOV DS,AX
MOV SI,0
MOV CX,100
LOOP_CHECK: MOV AL,DS:[SI]
CMP AL,1
JE ADD_NUM
ADD SI,2
JMP LOOP_CHECK1
ADD_NUM: MOV AL,NUM[0]
INC AL
ADD SI,2
MOV NUM[0],AL
LOOP_CHECK1:
LOOP LOOP_CHECK

MOV AL,NUM[0]
CMP AL,90
JNE CHECK_END
CALL YOU_WIN
CHECK_END:
POP SI
POP DX
POP CX
POP AX
RET
CHECK_PROC ENDP
;==================================================
;测试函数，用后删除
TEST1 PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
PUSH SI
MOV AX,mine_filed
MOV DS,AX
MOV BX,1660
MOV SI,0
MOV CX,10
LOOP_TEST1:
PUSH CX
PUSH BX
MOV CX,10
LOOP_TEST2:
MOV DL,DS:[SI]
ADD DL,48
MOV ES:[BX],DL
ADD BX,4
ADD SI,2
LOOP LOOP_TEST2
POP BX
POP CX
ADD BX,160
LOOP LOOP_TEST1
POP SI
POP DS
POP DX
POP CX
POP BX
POP AX
TEST1 ENDP

;==================================================

;键盘控制程序
CONTROL PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH ES

MOV AX,0B800H
MOV ES,AX

KEY_INPUT:
MOV AH,07H;07H不过滤控制字符，不回显，输入的字符存储在AL.
INT 21H

MOV CH,position[0]
MOV CL,position[1]
MOV BX,1661;BX用来存储光标所在的显存坐标
CMP AL,120;x退出
JNE CONTINUE_INPUT
MOV AX,4C00H
INT 21H
CONTINUE_INPUT:
CMP AL,119;w
JE UP

CMP AL,115;s
JE DOWN

CMP AL,97;a
JE LEFT

CMP AL,100;d
JE RIGHT

CMP AL,106;j
JE DETERMINE;按下j挖开光标所在单元格

CMP AL,107;k
JNE END_INPUT_TRANSFER

CALL SET_FLAG

JMP END_INPUT;选择分支结束后，直接跳出

UP: CMP CH,0
JE END_INPUT_TRANSFER

CALL RE_COLOR

DEC CH
MOV position[0],CH
JMP CH_COLOR

DOWN: CMP CH,9
JE END_INPUT_TRANSFER

CALL RE_COLOR

INC CH
MOV position[0],CH
JMP CH_COLOR

LEFT: CMP CL,0
JE END_INPUT_TRANSFER

CALL RE_COLOR

SUB CL,2
MOV position[1],CL
JMP CH_COLOR

RIGHT: CMP CL,18
JE END_INPUT_TRANSFER

CALL RE_COLOR

ADD CL,2
MOV position[1],CL
JMP CH_COLOR

;改变光标所在位置的颜色
CH_COLOR: MOV BX,1661
MOV AL,position[0]
MOV DL,160
MUL DL
ADD BX,AX
MOV AL,position[1]
MOV DH,2
MUL DH
ADD BX,AX
OR BYTE PTR ES:[BX],11000000B
OR BYTE PTR ES:[BX+2],11000000B
JMP END_INPUT

END_INPUT_TRANSFER:
JMP END_INPUT

DETERMINE:
CMP BYTE PTR FIRST[0],1
JE FIRST_J
CALL SET_EXPLORED
JMP END_INPUT

FIRST_J:
;将光标的位置送入第一次点击j点的坐标区
MOV AL,position[0]
MOV BYTE PTR FIRST_COORDINATE[0],AL
MOV AL,position[1]
MOV BYTE PTR FIRST_COORDINATE[1],AL
CALL SET_AROUND
CALL MINES_GENERATE
MOV AL,0
MOV FIRST[0],AL

CALL SET_EXPLORED
;观察随机数生成的情况
;CALL TEST1

END_INPUT:
POP ES
POP DX
POP CX
POP BX
POP AX
RET
CONTROL ENDP

SET_AROUND PROC
PUSH DX
MOV DH,position[0]
MOV DL,position[1]
DEC DH
SUB DL,2
MOV AROUND_X[0],DH
MOV AROUND_Y[0],DL

MOV DH,position[0]
MOV DL,position[1]
DEC DH
MOV AROUND_X[1],DH
MOV AROUND_Y[1],DL

MOV DH,position[0]
MOV DL,position[1]
DEC DH
ADD DL,2
MOV AROUND_X[2],DH
MOV AROUND_Y[2],DL

MOV DH,position[0]
MOV DL,position[1]
SUB DL,2
MOV AROUND_X[3],DH
MOV AROUND_Y[3],DL

MOV DH,position[0]
MOV DL,position[1]
ADD DL,2
MOV AROUND_X[4],DH
MOV AROUND_Y[4],DL

MOV DH,position[0]
MOV DL,position[1]
INC DH
SUB DL,2
MOV AROUND_X[5],DH
MOV AROUND_Y[5],DL

MOV DH,position[0]
MOV DL,position[1]
INC DH
MOV AROUND_X[6],DH
MOV AROUND_Y[6],DL

MOV DH,position[0]
MOV DL,position[1]
INC DH
ADD DL,2
MOV AROUND_X[7],DH
MOV AROUND_Y[7],DL

POP DX
RET
SET_AROUND ENDP

;随机数生成函数
RAND PROC
PUSH CX
PUSH DX
PUSH AX
STI
;MOV CL,change_flag[0]
;MOV CX,0
;CMP CX,0
JMP first_way
;JMP second_way
first_way:
MOV AL,1
MOV change_flag[0],AL
MOV AX,0
OUT 43H, AL;将数据传入控制字端口
IN AL, 40H   ;产生随机数AL
MOV DL,10;除10，产生0~9余数
DIV DL
MOV BL,AH
JMP pops
second_way:
MOV AL,0
MOV change_flag[0],AL
MOV AH,0;读时钟计数器值
INT 1AH
MOV AX,DX
AND AH,3
MOV DL,10;除10，产生0~9余数
DIV DL
MOV BL,AH;余数存BL，作随机
JMP pops
pops:
POP AX
POP DX
POP CX
RET
RAND ENDP
;设置explored已被探索区
SET_EXPLORED PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
;获取光标所在位置，放入BX
MOV DL,20
MOV AL,position[0]
MUL DL
MOV BX,AX
MOV AH,0
MOV AL,position[1]
ADD BX,AX
;把光标所在区设为已探索
MOV AX,explored
MOV DS,AX
MOV BYTE PTR DS:[BX],1
;显示已探索区域的数字
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,77;如果是雷
JNE CONTINUE_EX
CALL GAME_OVER
CONTINUE_EX:
ADD CL,48
MOV AL,position[0]
MOV CH,160
MUL CH
MOV BX,AX
MOV CH,2
MOV AL,position[1]
MUL CH
ADD BX,AX
ADD BX,1660
MOV ES:[BX],CL
;==========================================
;递归
CMP CL,48
JNE SET_EXPLORED_END
MOV DH,position[0]
MOV DL,position[1]
CALL RECURSION
;=========================================
SET_EXPLORED_END:
POP DS
POP DX
POP CX
POP BX
POP AX
RET
SET_EXPLORED ENDP

;递归过程
;DH存光标横坐标，DL存光标纵坐标
RECURSION PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
PUSH SI

;检测边缘
;如果当前坐标的下一坐标并未超出边界毕竟且尚未探索，则转向相应的方向
CALL DIR1
CALL DIR2
CALL DIR3
CALL DIR4
CALL DIR5
CALL DIR6
CALL DIR7
CALL DIR8
JMP RECURSION_END_TRANSFER

DIR1: PUSH DX
CMP DH,0
JE END_DR1
CMP DL,0
JE END_DR1
DEC DH
SUB DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR1
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR1
CALL RECURSION
END_DR1:
POP DX
RET

DIR2: PUSH DX
CMP DH,0
JE END_DR2
DEC DH
CALL IS_EXPLORED
CMP AL,0
JNE END_DR2
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR2
CALL RECURSION
END_DR2:
POP DX
RET

DIR3: PUSH DX
CMP DH,0
JE END_DR3
CMP DL,18
JE END_DR3
DEC DH
ADD DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR3
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR3
CALL RECURSION
END_DR3:
POP DX
RET

DIR4: PUSH DX
CMP DL,0
JE END_DR4
SUB DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR4
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR4
CALL RECURSION
END_DR4:
POP DX
RET

DIR5: PUSH DX
CMP DL,18
JE END_DR5
ADD DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR5
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR5
CALL RECURSION
END_DR5:
POP DX
RET

RECURSION_END_TRANSFER:
JMP RECURSION_END

DIR6: PUSH DX
CMP DH,9
JE END_DR6
CMP DL,0
JE END_DR6
INC DH
SUB DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR6
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR6
CALL RECURSION
END_DR6:
POP DX
RET

DIR7: PUSH DX
CMP DH,9
JE END_DR7
INC DH
CALL IS_EXPLORED
CMP AL,0
JNE END_DR7
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR7
CALL RECURSION
END_DR7:
POP DX
RET

DIR8: PUSH DX
CMP DH,9
JE END_DR8
CMP DL,18
JE END_DR8
INC DH
ADD DL,2
CALL IS_EXPLORED
CMP AL,0
JNE END_DR8
CALL SET_EX
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
CMP CL,0
JNE END_DR8
CALL RECURSION
END_DR8:
POP DX
RET

;检测是否为已探索
;AL放返回值，为0时为未探索
;BX为返回值，放坐标
IS_EXPLORED:
MOV CH,DH
MOV AL,20
MUL CH
MOV BH,0
MOV BL,DL
ADD BX,AX
MOV AX,explored
MOV DS,AX
MOV AL,1
MOV AH,DS:[BX]
CMP AH,AL
JE END_IS_EXPLORED
MOV AL,0
END_IS_EXPLORED:
RET

RECURSION_END:
POP SI
POP DS
POP DX
POP CX
POP BX
POP AX
RET
RECURSION ENDP

;该函数在递归函数中调用
SET_EX PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DS
PUSH SI
;选中区域设为已探索
MOV AX,explored
MOV DS,AX
MOV AL,DH
MOV BL,20
MUL BL
MOV BX,AX
MOV CL,DL
MOV CH,0
ADD BX,CX
MOV BYTE PTR DS:[BX],1
;显示对应位置数字
MOV AX,mine_filed
MOV DS,AX
MOV CL,DS:[BX]
ADD CL,48
MOV SI,1660
MOV BL,160
MOV AL,DH
MUL BL
MOV BL,DL
MOV BH,0
SHL BX,1
ADD SI,AX
ADD SI,BX
MOV ES:[SI],CL

POP SI
POP DS
POP DX
POP CX
POP BX
POP AX
RET
SET_EX ENDP


GAME_OVER PROC
PUSH AX
PUSH CX
PUSH SI
;MOV AH,02H
MOV SI,0
MOV CX,9
MOV BX,1180
LOOP_GAME_OVER: MOV DL,lose_str[SI]
MOV BYTE PTR ES:[BX+1],11110000B
MOV ES:[BX],DL
;INT 21H
ADD BX,2
INC SI
LOOP LOOP_GAME_OVER
CALL MUSIC
MOV AX,4C00H
INT 21H
POP SI
POP CX
POP AX
RET
GAME_OVER ENDP

YOU_WIN PROC
PUSH AX
PUSH CX
PUSH SI
;MOV AH,02H
MOV SI,0
MOV CX,7
MOV BX,1180
LOOP_YOU_WIN: MOV DL,win_str[SI]
MOV BYTE PTR ES:[BX+1],11110000B
MOV ES:[BX],DL
;INT 21H
INC SI
ADD BX,2
LOOP LOOP_YOU_WIN
CALL MUSIC
MOV AX,4C00H
INT 21H
POP SI
POP CX
POP AX
RET
YOU_WIN ENDP

;生成雷区子过程
;一局游戏只能调用一次
MINES_GENERATE PROC
push ax
push bx
push cx
push dx
push si

mov al,0
loop1: cmp al,10
je GENERATE_END
call RAND
mov dh,bl
call RAND
mov dl,bl
add dl,dl;列是偶数
mov si,0
mov ah,0
cmp dh,FIRST_COORDINATE[0]
jne loop2
cmp dl,FIRST_COORDINATE[1]
je loop1
loop2: cmp ax,si
je seta
cmp dh,x[si]
jne add_si
cmp dl,y[si]
je loop1
jmp add_si
loop loop2
loop loop1
add_si: inc si
jmp loop2

seta:
mov si,0
mov cx,8
loop3: cmp dh,AROUND_X[si]
jne add_sisi
cmp dl,AROUND_Y[si]
je loop1
add_sisi:
inc si
loop loop3
mov ah,0
mov bx,ax
mov x[bx],dh
mov y[bx],dl
inc al
jmp loop1

GENERATE_END:
CALL SET_MINE_FIELD
CALL SET_NUM
pop si
pop dx
pop cx
pop bx
pop ax
ret
MINES_GENERATE ENDP
;设置雷区数据
SET_MINE_FIELD PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DS

MOV DH,20
MOV AX,mine_filed
MOV DS,AX
MOV SI,0
MOV BX,0
MOV CX,10
LOOP_SET_FIELD1:
MOV AL,x[SI]
MUL DH
MOV BX,AX
MOV AL,y[SI]
ADD BX,AX
MOV BYTE PTR DS:[BX],77;A代表雷
INC SI
LOOP LOOP_SET_FIELD1

SET_FIELD_END:
POP DS
POP SI
POP DX
POP CX
POP BX
POP AX
RET
SET_MINE_FIELD ENDP
;设置无雷区域的数字
SET_NUM PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DS
;依次把10个雷周围的数字加一
MOV AX,mine_filed
MOV DS,AX
MOV SI,0
MOV CX,10
LOOP_SET_NUM:
;DX存储当前雷的左边
MOV DH,x[SI]
MOV DL,y[SI]
CALL DIRE1
CALL DIRE2
CALL DIRE3
CALL DIRE4
CALL DIRE5
CALL DIRE6
CALL DIRE7
CALL DIRE8
INC SI
LOOP LOOP_SET_NUM

;CALL SET_MINE_FIELD;修改被改动的雷区的数字
JMP SET_NUM_END
DIRE1:
CMP DH,1
JB NO_1
CMP DL,2
JB NO_1
MOV BX,DX
DEC BH
SUB BL,2
CALL MUL_POSITION
NO_1: NOP
RET

DIRE2:
CMP DH,1
JB NO_2
MOV BX,DX
DEC BH
CALL MUL_POSITION
NO_2: NOP
RET

DIRE3:
CMP DH,1
JB NO_3
CMP DL,16
JA NO_3
MOV BX,DX
DEC BH
ADD BL,2
CALL MUL_POSITION
NO_3: NOP
RET

DIRE4:
CMP DL,2
JB NO_4
MOV BX,DX
SUB BL,2
CALL MUL_POSITION
NO_4: NOP
RET

DIRE5:
CMP DL,16
JA NO_5
MOV BX,DX
ADD BL,2
CALL MUL_POSITION
NO_5: NOP
RET

DIRE6:
CMP DH,8
JA NO_6
CMP DL,2
JB NO_6
MOV BX,DX
INC BH
SUB BL,2
CALL MUL_POSITION
NO_6: NOP
RET

DIRE7:
CMP DH,8
JA NO_7
MOV BX,DX
INC BH
CALL MUL_POSITION
NO_7: NOP
RET

DIRE8:
CMP DH,8
JA NO_8
CMP DL,16
JA NO_8
MOV BX,DX
INC BH
ADD BL,2
CALL MUL_POSITION
NO_8: NOP
RET

INC_SI: INC SI
RET
;利用行和列坐标通过乘法来获取mine_field里的实际索引
;参数值为坐标，在bx里
;返回值为索引，在bx里
;把索引处的数值加一
MUL_POSITION:
MOV AL,20
MUL BH
MOV BH,0
ADD AX,BX
MOV BX,AX
MOV AL,DS:[BX]
CMP AL,77
JE END_MUL
INC AL
MOV DS:[BX],AL
END_MUL:
RET
SET_NUM_END:
POP DS
POP SI
POP DX
POP CX
POP BX
POP AX
RET

SET_NUM ENDP


;挖开单元格
DETERMINE_PROC PROC

RET
DETERMINE_PROC ENDP

code ends
end start
