import logging
import os
import tempfile

import azure.cognitiveservices.speech as speechsdk
from anyio import to_thread
from azure.core.exceptions import AzureError
from azure.identity import DefaultAzureCredential
from fastapi import APIRouter, File, HTTPException, UploadFile

from app.config import get_settings

logger = logging.getLogger(__name__)

router = APIRouter()

MAX_AUDIO_BYTES = 12 * 1024 * 1024
SPEECH_TOKEN_SCOPE = "https://cognitiveservices.azure.com/.default"


def _transcribe_wav(audio_bytes: bytes) -> tuple[str, str]:
    settings = get_settings()
    if not settings.azure_speech_endpoint or not settings.azure_speech_resource_id:
        raise RuntimeError("Azure Speech is not configured")

    credential = DefaultAzureCredential(
        managed_identity_client_id=settings.azure_client_id
    )
    access_token = credential.get_token(SPEECH_TOKEN_SCOPE)

    speech_config = speechsdk.SpeechConfig(endpoint=settings.azure_speech_endpoint)
    speech_config.authorization_token = (
        f"aad#{settings.azure_speech_resource_id}#{access_token.token}"
    )
    auto_detect = speechsdk.languageconfig.AutoDetectSourceLanguageConfig(
        languages=settings.azure_speech_languages
    )

    path = ""
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as audio_file:
            audio_file.write(audio_bytes)
            path = audio_file.name

        audio_config = speechsdk.audio.AudioConfig(filename=path)
        recognizer = speechsdk.SpeechRecognizer(
            speech_config=speech_config,
            audio_config=audio_config,
            auto_detect_source_language_config=auto_detect,
        )
        result = recognizer.recognize_once_async().get()

        if result.reason == speechsdk.ResultReason.RecognizedSpeech:
            detected = speechsdk.AutoDetectSourceLanguageResult(result).language
            return result.text, detected or "und"
        if result.reason == speechsdk.ResultReason.NoMatch:
            raise ValueError("No speech could be recognized")

        cancellation = speechsdk.CancellationDetails(result)
        logger.warning(
            "Speech recognition canceled: reason=%s error_code=%s details=%s",
            cancellation.reason,
            cancellation.error_code,
            cancellation.error_details,
        )
        raise RuntimeError("Speech recognition failed")
    finally:
        if path:
            try:
                os.unlink(path)
            except OSError:
                logger.warning("Could not remove temporary speech audio file", exc_info=True)


@router.post("/speech/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    if audio.content_type not in {"audio/wav", "audio/wave", "audio/x-wav"}:
        raise HTTPException(status_code=415, detail="Only WAV audio is supported")

    audio_bytes = await audio.read(MAX_AUDIO_BYTES + 1)
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="Audio recording is too large")
    if len(audio_bytes) < 44 or audio_bytes[:4] != b"RIFF" or audio_bytes[8:12] != b"WAVE":
        raise HTTPException(status_code=400, detail="Invalid WAV audio")

    try:
        text, language = await to_thread.run_sync(_transcribe_wav, audio_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except (AzureError, RuntimeError) as exc:
        logger.exception("Speech transcription failed")
        raise HTTPException(
            status_code=503, detail="Speech transcription is temporarily unavailable"
        ) from exc

    return {"text": text, "language": language}