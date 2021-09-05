; remember Backface culling
; Scanline rendering
; Clipping
; make sure byte_dec_to_str is as fast as can be.

SYS_EXIT  			equ 1
SYS_READ  			equ 3
SYS_WRITE 			equ 4
SYS_IOCTL 			equ 54
STDIN     			equ 0
STDOUT    			equ 1
ICANON    			equ 2
ISIG 		 			equ 1
ECHO    	 			equ 8
TCGETS    			equ 0x5401
TCSETS    			equ 0x5402

%macro write_string 2 
   mov   eax, SYS_WRITE
   mov   ebx, STDOUT
   mov   ecx, %1
   mov   edx, %2
   int   0x80
%endmacro

section	.text
	global _start
_start:

	mov ebx, color

	call set_color

	mov eax, value
	
	call print_dec

	call reset_attribs

	; mov eax, res_vector
	; mov ebx,	test_vec

	; call process_vertex


	; rdtscp
	; rdseed

	; write_string res_vector, 4
	; write_string res_vector + 4, 4
	; write_string res_vector + 8, 4



	; call clear

	; mov eax, SYS_IOCTL	
	; mov ebx, STDIN
	; mov ecx, TCGETS
	; mov edx, termios
	; int 0x80

	; mov eax, ICANON
	; not eax
	; and [termios + 12], eax
	; mov eax, ECHO
	; not eax
	; and [termios + 12], eax
	; mov eax, ISIG
	; not eax
	; and [termios + 12], eax

	; mov eax, SYS_IOCTL
	; mov ebx, STDIN
	; mov ecx, TCSETS
	; mov edx, termios
	; int 0x80

	; call hide_cursor

	; call print_input

	; call clear

	; call show_cursor

	; or [termios + 12], byte ICANON
	; or [termios + 12], byte ECHO
	; or [termios + 12], byte ISIG

	; mov eax, SYS_IOCTL
	; mov ebx, STDIN
	; mov ecx, TCSETS
	; mov edx, termios
	; int 0x80

	mov eax, SYS_EXIT	
	int 0x80

clear:
	mov [ansii + 2], byte '2'
	mov [ansii + 3], byte 'J'
	write_string ansii, 4
	ret

hide_cursor:
	mov [ansii + 2], byte '?'
	mov [ansii + 3], byte '2'
	mov [ansii + 4], byte '5'
	mov [ansii + 5], byte 'l'
	write_string ansii, 6
	ret

show_cursor:
	mov [ansii + 2], byte '?'
	mov [ansii + 3], byte '2'
	mov [ansii + 4], byte '5'
	mov [ansii + 5], byte 'h'
	write_string ansii, 6
	ret

color_mode:
	mov [ansii + 2], byte '='
	mov [ansii + 3], byte '1'
	mov [ansii + 4], byte '9'
	mov [ansii + 5], byte 'h'
	write_string ansii, 6
	ret

reset_attribs:
	mov [ansii + 2], byte '0'
	mov [ansii + 3], byte 'm'
	write_string ansii, 4
	ret

set_color: ; params are ebx(byte[3]) each in range 0-5
	
	enter 1, 0

	mov [ansii + 2], byte '4'
	mov [ansii + 3], byte '8'
	mov [ansii + 4], byte ';'
	mov [ansii + 5], byte '5'
	mov [ansii + 6], byte ';'

	; construct code

	mov al, byte 36
	mov dl, byte [ebx]
	mul dl

	mov [esp], byte al

	mov al, byte 6
	mov dl, byte [ebx + 1]
	mul dl

	add [esp], byte al

	mov dl, byte [ebx + 2]

	add [esp], byte dl

	add [esp], byte 16

	; done

	mov eax, esp

	mov edx, ansii + 7

	call byte_dec_to_str ; increments edx by length

	mov [edx], byte 'm'

	inc edx

	sub edx, ansii

	write_string ansii, edx

	leave

	ret

cursor_back:
	mov [ansii + 2], byte '['
	mov [ansii + 3], byte '1'
	mov [ansii + 4], byte 'D'
	write_string ansii, 5
	ret

print_input:
	
	mov eax, SYS_READ
	mov ebx, STDIN
	mov ecx, input
	mov edx, 8
	int 0x80

	call cursor_back

	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, blank
	mov edx, 1
	int 0x80

	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, input
	mov edx, 8
	int 0x80

	call cursor_back

	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, character
	mov edx, 1
	int 0x80

	cmp byte [input], 'q'
	jne print_input

	ret


dot4: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec4 *)s


	fld  dword [ebx] ; st0
	fmul dword [ecx] ; st0 = st0 * ecx.x

	fld  dword [ebx + 4] ; st1
	fmul dword [ecx + 4] ; st1 = st1 * ecx.y

	faddp st1 ; add st1 to st0 and pop it from the stack

	fld  dword [ebx + 8] ; st1
	fmul dword [ecx + 8] ; st1 = st1 * ecx.z

	faddp st1 ; add st1 to st0 and pop it from the stack

	fld  dword [ebx + 12] ; st1
	fmul dword [ecx + 12] ; st1 = st1 * ecx.w

	faddp st1 ; add st1 to st0 and pop it from the stack

	fstp dword [eax] ; store into eax and pop from stack

	ret

vec4_matrix4x4_mult: ; result is stored in [eax] and parameters are (ebx(vec4 *), and ecx(matrix4x4 *))

	push ecx
	push eax

	call dot4 ; result gets stored in location of x
	add ecx, 16 ; 16 bytes = 4 floats, resulting in the next row

	add eax, 4
	call dot4 
	add ecx, 16 

	add eax, 4
	call dot4 
	add ecx, 16 

	add eax, 4
	call dot4 

	pop eax
	pop ecx

	ret

dot3: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	fld  dword [ebx] ; st0
	fmul dword [ecx] ; st0 = st0 * ecx.x

	fld  dword [ebx + 4] ; st1
	fmul dword [ecx + 4] ; st1 = st1 * ecx.y

	faddp st1 ; add st1 to st0 and pop it from the stack

	fld  dword [ebx + 8] ; st1
	fmul dword [ecx + 8] ; st1 = st1 * ecx.z

	faddp st1 ; add st1 to st0 and pop it from the stack

	fstp dword [eax] ; store into eax and pop from stack

	ret

vec3_matrix3x3_mult: ; result is stored in [eax] and parameters are (ebx(vec3 *), and ecx(matrix3x3 *))

	push ecx
	push eax

	call dot3 ; result gets stored in location of x
	add ecx, 16 ; 16 bytes = 4 floats, resulting in the next row

	add eax, 4 ; offset to the next component (y)
	call dot3 
	add ecx, 16 

	add eax, 4
	call dot3 

	pop eax
	pop ecx

	ret

vec3_mag: ; result is stored in [eax], parameter ebx(vec3 *)

	fld  dword [ebx] ; st0
	fmul st0 ; st0 = st0 * st0

	fld  dword [ebx + 4] ; st1
	fmul st1 ; st1 = st1 * st1

	faddp st1 ; add st1 to st0 and pop it from the stack

	fld  dword [ebx + 8] ; st1
	fmul st1 ; st1 = st1 * st1

	faddp st1 ; add st1 to st0 and pop it from the stack

	fsqrt ; sqrt s0

	fstp dword [eax] ; store and pop.

	ret

vec3_cross: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	; x

	; st0
	fld dword [ebx + 4] ; 1.y
	fmul dword [ecx + 8] ; 1.y * 2.z

	; st1
	fld dword [ebx + 8] ; 1.z
	fmul dword [ecx + 4] ; 1.z * 2.y

	fsubp st1 ; (st0 - st1) and pop st1 from the stack
	fstp dword [eax] ; pop st0 and store in (eax.x (0 bytes from the start))

	; y

	fld dword [ebx + 8] ; 1.z
	fmul dword [ecx] ; 2.x

	fld dword [ebx] ; 1.x
	fmul dword [ecx + 8] ; 2.z

	fsubp st1
	fstp dword [eax + 4]

	; z

	fld dword [ebx] ; 1.x
	fmul dword [ecx + 4] ; 2.y

	fld dword [ebx + 4] ; 1.y
	fmul dword [ecx] ; 2.x

	fsubp st1
	fstp dword [eax + 8]

	ret

vec3_mult_vec3: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	fld dword [ebx]
	fmul dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fmul dword [ecx + 4]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fmul dword [ecx + 8]
	fstp dword [eax + 8]

	ret

vec3_div_vec3: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	fld dword [ebx]
	fdiv dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fdiv dword [ecx + 4]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fdiv dword [ecx + 8]
	fstp dword [eax + 8]

	ret

vec3_add_vec3: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	fld dword [ebx]
	fadd dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fadd dword [ecx + 4]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fadd dword [ecx + 8]
	fstp dword [eax + 8]

	ret

vec3_sub_vec3: ; result is stored in [eax], parameters are (ebx and ecx) storing (vec3 *)s

	fld dword [ebx]
	fsub dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fsub dword [ecx + 4]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fsub dword [ecx + 8]
	fstp dword [eax + 8]

	ret

vec3_mult_num: ; result is stored in [eax] and parameters are ( ebx(vec3 *) and ecx(float *) )

	fld dword [ebx]
	fmul dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fmul dword [ecx]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fmul dword [ecx]
	fstp dword [eax + 8]

	ret

vec3_add_num:; result is stored in [eax] and parameters are ( ebx(vec3 *) and ecx(float *) )

	fld dword [ebx]
	fadd dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fadd dword [ecx]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fadd dword [ecx]
	fstp dword [eax + 8]

	ret

vec3_sub_num:; result is stored in [eax] and parameters are ( ebx(vec3 *) and ecx(float *) )

	fld dword [ebx]
	fsub dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fsub dword [ecx]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fsub dword [ecx]
	fstp dword [eax + 8]

	ret

vec3_div_num:; result is stored in [eax] and parameters are ( ebx(vec3 *) and ecx(float *) )

	fld dword [ebx]
	fdiv dword [ecx]
	fstp dword [eax]

	fld dword [ebx + 4]
	fdiv dword [ecx]
	fstp dword [eax + 4]

	fld dword [ebx + 8]
	fdiv dword [ecx]
	fstp dword [eax + 8]

	ret

vec3_normalize: ; result is stored in [eax] and parameters are ebx (vec3 *)

	enter 4, 0

	push eax
	mov eax, esp
	call vec3_mag
	mov ecx, eax
	pop eax

	call vec3_div_num

	leave
	ret

process_vertex: ; result is stored in [eax] and parameters are ebx(vec4 *)


	enter 16, 0 ; alloc enough for a vec4

	mov edx, esp ; move the stack pointer into edx, since the next push increases it.

	push eax ; push into stack

	mov eax, edx

	mov ecx, perspective_matrix

	call vec4_matrix4x4_mult

	pop eax

	mov ebx, edx
	mov ecx, edx
	add ecx, 12 ; &result.w
	

	; perspective divide
	call vec3_div_num


	; map to screen
	fld dword [eax]
	fadd dword [one]
	fmul dword [halfres]
	fistp dword [eax]

	fld dword [eax + 4]
	fadd dword [one]
	fmul dword [halfres]
	fistp dword [eax + 4]

	leave

	ret


byte_dec_to_str: ; 0-256, result stored in [edx], and edx is increased by the number of characters added, parameter is eax (int *)
	
	enter 16, 0

	mov ecx, esp
	add ecx, 16

	mov ax, [eax]

	str_to_ascii_rev:
		dec 	ecx
	   mov 	bl, 10
	   div 	bl
	   add 	ah, byte '0'
		mov 	[ecx], byte ah
		mov 	[edx], al 
		mov 	ax, [edx]
	   cmp 	ax, 0
	   jne 	str_to_ascii_rev

	mov ebx, esp
	add ebx, 16

	str_to_ascii_copy:
		mov 	eax, [ecx]
		mov 	[edx], eax
		inc 	ecx
		inc 	edx
	   cmp 	ecx, ebx
	   jl 	str_to_ascii_copy

   leave

	ret


print_dec: ; 0 - 256 param eax(int *)

	enter 16, 0
	
	mov edx, esp

	call byte_dec_to_str

	; edx stores the current position of the string ( esp + length )
	; subtract esp to get the length
   sub  edx, esp
   ; edx is also the length for printing strings, so no need to move.

   mov   ecx, esp
   mov   eax, SYS_WRITE
   mov   ebx, STDOUT
   int   0x80

   mov [esp], byte 10

   mov   eax, SYS_WRITE
   mov   ebx, STDOUT
   mov   edx, 1
   mov   ecx, esp
   int   0x80

   leave

	ret


section .bss
	termios resb 36
	input resb 8
	tmp_matrix resd 16
	res_matrix resd 16
	tmp_vector resd 4
	res_vector resd 4
	fd_out resd 1

section .data
	
	ansii db 0x1b, "["
	times 16 db 0 ; increase ansii length
	
	character db "@"
	color db 0, 0, 5

	blank db " "
	value db 233
	
	identity_matrix dd 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0
	
	inv_resolution dd 0.015625
	halfres dd 32.0
	one dd 1.0

	resolution dd 64.0
	perspective_matrix dd 1.732113, 0.0, 0.0, 0.0, 0.0, 1.732113, 0.0, 0.0, 0.0, 0.0, 0.010305, -2.020202, 0.0, 0.0, -1.0, 0.0
	
	test_vec dd 10.0, 23.0, 12.0, 1.0

	file_name db "test.txt", 0
	file_name_len db $ - file_name


; void Math_LookAt(float *ret, Vec3 eye, Vec3 center, Vec3 up){

;     Vec3 z = Math_Vec3Normalize(Math_Vec3SubVec3(eye, center));  // Forward
;     // Vec3 x = Math_Vec3Normalize(Math_Vec3Cross(up, z)); // Right
;     Vec3 x = Math_Vec3Normalize(Math_Vec3Cross(up, z)); // Right
;     Vec3 y = Math_Vec3Normalize(Math_Vec3Cross(z, x));

;     ret[0] = x.x;
;     ret[1] = x.y;
;     ret[2] = x.z;
;     ret[3] = -(Math_Vec3Dot(x, eye));
;     ret[4] = y.x;
;     ret[5] = y.y;
;     ret[6] = y.z;
;     ret[7] = -(Math_Vec3Dot(y, eye));
;     ret[8] =  z.x;
;     ret[9] =  z.y;
;     ret[10] = z.z;
;     ret[11] = -(Math_Vec3Dot(z, eye));
;     ret[12] = 0;
;     ret[13] = 0;
;     ret[14] = 0;
;     ret[15] = 1;
; }

; void Math_RotateMatrix(float *matrix, Vec3 angles){

;     float sx = sin(angles.x);
;     float cx = cos(angles.x);
;     float sy = sin(angles.y);
;     float cy = cos(angles.y);
;     float sz = sin(angles.z);
;     float cz = cos(angles.z);

;     matrix[0] = cy*cz;
;     matrix[1] = (-cy*sz*cx) + (sy*sx);
;     matrix[2] = (cy*sz*sx) + (sy*cx);
;     matrix[3] = 0;
;     matrix[4] = sz;
;     matrix[5] = cz*cx;
;     matrix[6] = -cz*sx;
;     matrix[7] = 0;
;     matrix[8] = -sy*cz;
;     matrix[9] = (sy*sz*cx) + (cy*sx);
;     matrix[10] = (-sy*sz*sx) + (cy*cx);
;     matrix[11] = 0;
;     matrix[12] = 0;
;     matrix[13] = 0;
;     matrix[14] = 0;
;     matrix[15] = 1;
; }

; Vec4 Math_MatrixMult4( Vec4 vert, float *matrix){
;     Vec4 out;
;     out.x = ((vert.x * matrix[0])  + (vert.y * matrix[1])  + (vert.z * matrix[2])  + (vert.w * matrix[3]));
;     out.y = ((vert.x * matrix[4])  + (vert.y * matrix[5])  + (vert.z * matrix[6])  + (vert.w * matrix[7]));
;     out.z = ((vert.x * matrix[8])  + (vert.y * matrix[9])  + (vert.z * matrix[10]) + (vert.w * matrix[11]));
;     out.w = ((vert.x * matrix[12]) + (vert.y * matrix[13]) + (vert.z * matrix[14]) + (vert.w * matrix[15]));
;     return out;
; }

; Vec3 Math_MatrixMult3( Vec3 vert, float *matrix){
;     Vec3 out;
;     out.x = ((vert.x * matrix[0])  + (vert.y * matrix[1])  + (vert.z * matrix[2]));
;     out.y = ((vert.x * matrix[4])  + (vert.y * matrix[5])  + (vert.z * matrix[6]));
;     out.z = ((vert.x * matrix[8])  + (vert.y * matrix[9])  + (vert.z * matrix[10]));
;     return out;
; }

; void Math_MatrixMatrixMult(float *res, float *a, float *b){
    
;     float m[16];

;     m[0] = (a[0]  * b[0]) + (a[1]  *  b[4]) + (a[2]  * b[8])  + (a[3]  * b[12]);
;     m[1] = (a[0]  * b[1]) + (a[1]  *  b[5]) + (a[2]  * b[9])  + (a[3]  * b[13]);
;     m[2] = (a[0]  * b[2]) + (a[1]  *  b[6]) + (a[2]  * b[10]) + (a[3]  * b[14]);
;     m[3] = (a[0]  * b[3]) + (a[1]  *  b[7]) + (a[2]  * b[11]) + (a[3]  * b[15]);
;     m[4] = (a[4]  * b[0]) + (a[5]  *  b[4]) + (a[6]  * b[8])  + (a[7]  * b[12]);
;     m[5] = (a[4]  * b[1]) + (a[5]  *  b[5]) + (a[6]  * b[9])  + (a[7]  * b[13]);
;     m[6] = (a[4]  * b[2]) + (a[5]  *  b[6]) + (a[6]  * b[10]) + (a[7]  * b[14]);
;     m[7] = (a[4]  * b[3]) + (a[5]  *  b[7]) + (a[6]  * b[11]) + (a[7]  * b[15]);
;     m[8] = (a[8]  * b[0]) + (a[9]  *  b[4]) + (a[10] * b[8])  + (a[11] * b[12]);
;     m[9] = (a[8]  * b[1]) + (a[9]  *  b[5]) + (a[10] * b[9])  + (a[11] * b[13]);
;     m[10] = (a[8]  * b[2]) + (a[9]  *  b[6]) + (a[10] * b[10]) + (a[11] * b[14]);
;     m[11] = (a[8]  * b[3]) + (a[9]  *  b[7]) + (a[10] * b[11]) + (a[11] * b[15]);
;     m[12] = (a[12] * b[0]) + (a[13] *  b[4]) + (a[14] * b[8])  + (a[15] * b[12]);
;     m[13] = (a[12] * b[1]) + (a[13] *  b[5]) + (a[14] * b[9])  + (a[15] * b[13]);
;     m[14] = (a[12] * b[2]) + (a[13] *  b[6]) + (a[14] * b[10]) + (a[15] * b[14]);
;     m[15] = (a[12] * b[3]) + (a[13] *  b[7]) + (a[14] * b[11]) + (a[15] * b[15]);

;     memcpy(res, m, sizeof(float) * 16);
; }

; void Math_MatrixMatrixMult3x3(float *res, float *a, float *b){
    
;     float m[16];

;     m[0] = (a[0] * b[0]) + (a[1] * b[3]) + (a[2] * b[6]);
;     m[1] = (a[0] * b[1]) + (a[1] * b[4]) + (a[2] * b[7]);
;     m[2] = (a[0] * b[2]) + (a[1] * b[5]) + (a[2] * b[8]);
;     m[3] = (a[3] * b[0]) + (a[4] * b[3]) + (a[5] * b[6]);
;     m[4] = (a[3] * b[1]) + (a[4] * b[4]) + (a[5] * b[7]);
;     m[5] = (a[3] * b[2]) + (a[4] * b[5]) + (a[5] * b[8]);
;     m[6] = (a[6] * b[0]) + (a[7] * b[3]) + (a[8] * b[6]);
;     m[7] = (a[6] * b[1]) + (a[7] * b[4]) + (a[8] * b[7]);
;     m[8] = (a[6] * b[2]) + (a[7] * b[5]) + (a[8] * b[8]);

;     memcpy(res, m, sizeof(float) * 16);
; }
