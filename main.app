import streamlit as st
import pdfplumber
from openai import OpenAI

def read_file(file):
    if file.type == "application/pdf":
        with pdfplumber.open(file) as pdf:
            return "\n".join(page.extract_text() for page in pdf.pages)
    elif file.type == "text/plain":
        return file.getvalue().decode("utf-8")
    else:
        st.error("지원하지 않는 파일 형식입니다.")
        return None

def process_text_with_chatgpt(text, client, instructions=""):
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": f"{instructions}\n\nPlease preprocess the following text:\n\n{text}"},
            ],
            temperature=0.1,
            max_tokens=2000,
        )
        return response.choices[0].message.content
    except Exception as e:
        st.error(f"ChatGPT API 오류: {str(e)}")
        return None

def compare_texts(text1, text2, client):
    try:
        prompt = f"""
        다음 텍스트들을 비교하고 유사도를 평가하세요.
        텍스트 2의 각 주장이 텍스트 1에 포함되어 있는지 표시하세요.
        유사한 표현/단어는 동일한 것으로 간주하세요.

        텍스트 1 (선출원 명세서):
        {text1}

        텍스트 2 (후출원 청구항):
        {text2}

        결과 형식:
        | 청구항 | 포함 여부 | 유사도 (매우 높음, 높음, 중간, 낮음, 매우 낮음) |
        |---|---|---|
        | ...  | ...        | ...                                             |

        결과를 요약해주세요.
        """
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.1,
            max_tokens=1500,
        )
        return response.choices[0].message.content
    except Exception as e:
        st.error(f"ChatGPT API 오류: {str(e)}")
        return None

def main():
    st.title("문서 비교 도구 (ChatGPT)")

    # 세션 상태 초기화
    if 'processed_text1' not in st.session_state:
        st.session_state.processed_text1 = None
    if 'processed_text2' not in st.session_state:
        st.session_state.processed_text2 = None

    # 사이드바에서 API 키 입력
    with st.sidebar:
        api_key = st.text_input("ChatGPT API 키", type="password")
        if api_key:
            client = OpenAI(api_key=api_key)
            st.success("API 키가 설정되었습니다.")
        else:
            st.warning("API 키를 입력해주세요.")
            st.stop()

    # 메인 페이지 레이아웃
    col1, col2 = st.columns(2)

    with col1:
        st.subheader("비교 대상 명세서 (텍스트 1)")
        input_type_1 = st.radio("입력 방식 선택 (텍스트 1)", ["텍스트 직접 입력", "파일 업로드"], key="input_type_1")
        
        if input_type_1 == "텍스트 직접 입력":
            text1 = st.text_area("텍스트 1 입력", height=300, key="text1")
            if text1:
                with st.spinner("텍스트 처리 중..."):
                    st.session_state.processed_text1 = process_text_with_chatgpt(text1, client)
        else:
            uploaded_file1 = st.file_uploader("파일 업로드 (텍스트 1)", type=["pdf", "txt"], key="file1")
            if uploaded_file1:
                with st.spinner("파일 처리 중..."):
                    text1 = read_file(uploaded_file1)
                    if text1:
                        st.text_area("추출된 텍스트", value=text1, height=300, key="extracted_text1")
                        st.session_state.processed_text1 = process_text_with_chatgpt(text1, client)

    with col2:
        st.subheader("비교 대상 청구항 (텍스트 2)")
        input_type_2 = st.radio("입력 방식 선택 (텍스트 2)", ["텍스트 직접 입력", "파일 업로드"], key="input_type_2")
        
        if input_type_2 == "텍스트 직접 입력":
            text2 = st.text_area("텍스트 2 입력", height=300, key="text2")
            if text2:
                with st.spinner("텍스트 처리 중..."):
                    st.session_state.processed_text2 = process_text_with_chatgpt(text2, client)
        else:
            uploaded_file2 = st.file_uploader("파일 업로드 (텍스트 2)", type=["pdf", "txt"], key="file2")
            if uploaded_file2:
                with st.spinner("파일 처리 중..."):
                    text2 = read_file(uploaded_file2)
                    if text2:
                        st.text_area("추출된 텍스트", value=text2, height=300, key="extracted_text2")
                        st.session_state.processed_text2 = process_text_with_chatgpt(text2, client)

    additional_instructions = st.text_area("AI에게 추가 지시사항 (선택)", key="instructions")

    if st.button("비교 시작"):
        if st.session_state.processed_text1 and st.session_state.processed_text2:
            with st.spinner("텍스트 비교 중..."):
                result = compare_texts(st.session_state.processed_text1, st.session_state.processed_text2, client)
                if result:
                    st.subheader("비교 결과")
                    st.write(result)
                else:
                    st.error("텍스트 비교 중 오류가 발생했습니다.")
        else:
            st.error("두 텍스트를 모두 입력하고 처리해주세요.")

if __name__ == "__main__":
    main()
